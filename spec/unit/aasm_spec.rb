require File.join(File.dirname(__FILE__), '..', 'spec_helper')

class Foo
  include AASM
  initial_state :open
  state :open, :exit => :exit
  state :closed, :enter => :enter

  event :close, :success => :success_callback do
    transitions :to => :closed, :from => [:open]
  end

  event :null do
    transitions :to => :closed, :from => [:open], :guard => :always_false
  end

  def always_false
    false
  end

  def success_callback
  end

  def enter
  end
  def exit
  end
end

class Bar
  include AASM

  state :read
  state :ended

  event :foo do
    transitions :to => :ended, :from => [:read]
  end
end

class Baz < Bar
end


describe AASM, '- class level definitions' do
  it 'should define a class level initial_state() method on its including class' do
    Foo.should respond_to(:initial_state)
  end

  it 'should define a class level state() method on its including class' do
    Foo.should respond_to(:state)
  end

  it 'should define a class level event() method on its including class' do
    Foo.should respond_to(:event)
  end
  
  it 'should define a class level states() method on its including class' do
    Foo.should respond_to(:states)
  end
  
  it 'should define a class level states_for_select() method on its including class' do
    Foo.should respond_to(:states_for_select)
  end

  it 'should define a class level events() method on its including class' do
    Foo.should respond_to(:events)
  end

end


describe AASM, '- states_for_select' do
  it "should return a select friendly array of states in the form of [['Friendly name', 'state_name']]" do
    Foo.states_for_select.should == [['Open', 'open'], ['Closed', 'closed']]
  end
end

describe AASM, '- instance level definitions' do
  before(:each) do
    @foo = Foo.new
  end

  it 'should define a state querying instance method on including class' do
    @foo.should respond_to(:open?)
  end

  it 'should define an event! inance method' do
    @foo.should respond_to(:close!)
  end
end

describe AASM, '- initial states' do
  before(:each) do
    @foo = Foo.new
    @bar = Bar.new
  end

  it 'should set the initial state' do
    @foo.current_state.should == :open
  end

  it '#open? should be initially true' do
    @foo.open?.should be_true
  end

  it '#closed? should be initially false' do
    @foo.closed?.should be_false
  end

  it 'should use the first state defined if no initial state is given' do
    @bar.current_state.should == :read
  end
end

describe AASM, '- event firing with persistence' do
  it 'should fire the Event' do
    foo = Foo.new

    Foo.events[:close].should_receive(:fire).with(foo)
    foo.close!
  end

  it 'should update the current state' do
    foo = Foo.new
    foo.close!

    foo.current_state.should == :closed
  end

  it 'should call the success callback if one was provided' do
    foo = Foo.new

    foo.should_receive(:success_callback)

    foo.close!
  end

  it 'should attempt to persist if write_state is defined' do
    foo = Foo.new
    
    def foo.write_state
    end

    foo.should_receive(:write_state)

    foo.close!
  end

  it 'should return true if write_state is defined and returns true' do
    foo = Foo.new
    
    def foo.write_state(state)
      true
    end

    foo.close!.should be_true
  end

  it 'should return false if write_state is defined and returns false' do
    foo = Foo.new
    
    def foo.write_state(state)
      false
    end

    foo.close!.should be_false
  end

  it "should not update the current_state if the write fails" do
    foo = Foo.new
    
    def foo.write_state
      false
    end

    foo.should_receive(:write_state)

    foo.close!
    foo.current_state.should == :open
  end
end

describe AASM, '- event firing without persistence' do
  it 'should fire the Event' do
    foo = Foo.new

    Foo.events[:close].should_receive(:fire).with(foo)
    foo.close
  end

  it 'should update the current state' do
    foo = Foo.new
    foo.close

    foo.current_state.should == :closed
  end

  it 'should attempt to persist if aasm_write_state is defined' do
    foo = Foo.new
    
    def foo.write_state
    end

    foo.should_receive(:write_state_without_persistence)

    foo.close
  end
end

describe AASM, '- persistence' do
  it 'should read the state if it has not been set and read_state is defined' do
    foo = Foo.new
    def foo.read_state
    end

    foo.should_receive(:read_state)

    foo.current_state
  end
end

describe AASM, '- getting events for a state' do
  it '#events_for_current_state should use current state' do
    foo = Foo.new
    foo.should_receive(:current_state)
    foo.events_for_current_state
  end

  it '#events_for_current_state should use events_for_state' do
    foo = Foo.new
    foo.stub!(:current_state).and_return(:foo)
    foo.should_receive(:events_for_state).with(:foo)
    foo.events_for_current_state
  end
end

describe AASM, '- event callbacks' do
  it 'should call event_fired if defined and successful for bang fire' do
    foo = Foo.new
    def foo.event_fired(from, to)
    end

    foo.should_receive(:event_fired)

    foo.close!
  end

  it 'should not call event_fired if defined but persist fails for bang fire' do
    foo = Foo.new
    def foo.event_fired(from, to)
    end
    foo.stub!(:set_current_state_with_persistence).and_return(false)

    foo.should_not_receive(:event_fired)

    foo.close!
  end

  it 'should not call event_failed if defined and persist fails for bang fire' do
    foo = Foo.new
    def foo.event_failed(from, to)
    end
    foo.stub!(:set_current_state_with_persistence).and_return(false)

    foo.should_receive(:event_failed)

    foo.close!
  end

  it 'should call event_fired if defined and successful for non-bang fire' do
    foo = Foo.new
    def foo.event_fired(from, to)
    end

    foo.should_receive(:event_fired)

    foo.close
  end

  it 'should call event_failed if defined and transition failed for bang fire' do
    foo = Foo.new
    def foo.event_failed(event)
    end

    foo.should_receive(:event_failed)

    foo.null!
  end

  it 'should call event_failed if defined and transition failed for non-bang fire' do
    foo = Foo.new
    def foo.aasm_event_failed(event)
    end

    foo.should_receive(:event_failed)

    foo.null
  end
end

describe AASM, '- state actions' do
  it "should call enter when entering state" do
    foo = Foo.new
    foo.should_receive(:enter)

    foo.close
  end

  it "should call exit when exiting state" do
    foo = Foo.new
    foo.should_receive(:exit)

    foo.close
  end
end


describe Baz do
  it "should have the same states as it's parent" do
    Baz.states.should == Bar.states
  end

  it "should have the same events as it's parent" do
    Baz.events.should == Bar.events
  end
end


class ChetanPatil
  include AASM
  initial_state :sleeping
  state :sleeping
  state :showering
  state :working
  state :dating

  event :wakeup do
    transitions :from => :sleeping, :to => [:showering, :working]
  end

  event :dress do
    transitions :from => :sleeping, :to => :working, :on_transition => :wear_clothes
    transitions :from => :showering, :to => [:working, :dating], :on_transition => Proc.new { |obj, *args| obj.wear_clothes(*args) }
  end

  def wear_clothes(shirt_color, trouser_type)
  end
end


describe ChetanPatil do
  it 'should transition to specified next state (sleeping to showering)' do
    cp = ChetanPatil.new
    cp.wakeup! :showering
    
    cp.current_state.should == :showering
  end

  it 'should transition to specified next state (sleeping to working)' do
    cp = ChetanPatil.new
    cp.wakeup! :working

    cp.current_state.should == :working
  end

  it 'should transition to default (first or showering) state' do
    cp = ChetanPatil.new
    cp.wakeup!

    cp.current_state.should == :showering
  end

  it 'should transition to default state when on_transition invoked' do
    cp = ChetanPatil.new
    cp.dress!(nil, 'purple', 'dressy')

    cp.current_state.should == :working
  end

  it 'should call on_transition method with args' do
    cp = ChetanPatil.new
    cp.wakeup! :showering

    cp.should_receive(:wear_clothes).with('blue', 'jeans')
    cp.dress! :working, 'blue', 'jeans'
  end

  it 'should call on_transition proc' do
    cp = ChetanPatil.new
    cp.wakeup! :showering

    cp.should_receive(:wear_clothes).with('purple', 'slacks')
    cp.dress!(:dating, 'purple', 'slacks')
  end
end
