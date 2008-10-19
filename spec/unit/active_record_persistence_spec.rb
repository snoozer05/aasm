require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'aasm')

begin
  require 'rubygems'
  require 'active_record'

  # A dummy class for mocking the activerecord connection class
  class Connection
  end

  class FooBar < ActiveRecord::Base
    include AASM

    # Fake this column for testing purposes
    attr_accessor :state

    state :open
    state :closed

    event :view do
      transitions :to => :read, :from => [:needs_attention]
    end
  end

  class Fi < ActiveRecord::Base
    def read_state
      "fi"
    end    
    include AASM
  end

  class Fo < ActiveRecord::Base
    def write_state(state)
      "fo"
    end    
    include AASM
  end

  class Fum < ActiveRecord::Base
    def write_state_without_persistence(state)
      "fum"
    end    
    include AASM
  end

  class June < ActiveRecord::Base
    include AASM
    state_column :status
  end
  
  class Beaver < June
  end

  describe "aasm model", :shared => true do
    it "should include AASM::Persistence::ActiveRecordPersistence" do
      @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence)
    end    
    it "should include AASM::Persistence::ActiveRecordPersistence::InstanceMethods" do
      @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::InstanceMethods)
    end    
  end

  describe FooBar, "class methods" do
    before(:each) do
      @klass = FooBar
    end
    it_should_behave_like "aasm model"
    it "should include AASM::Persistence::ActiveRecordPersistence::ReadState" do
      @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::ReadState)
    end    
    it "should include AASM::Persistence::ActiveRecordPersistence::WriteState" do
      @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::WriteState)
    end    
    it "should include AASM::Persistence::ActiveRecordPersistence::WriteStateWithoutPersistence" do
      @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::WriteStateWithoutPersistence)
    end    
  end

  describe Fi, "class methods" do
    before(:each) do
      @klass = Fi
    end
    it_should_behave_like "aasm model"
    it "should not include AASM::Persistence::ActiveRecordPersistence::ReadState" do
      @klass.included_modules.should_not be_include(AASM::Persistence::ActiveRecordPersistence::ReadState)
    end    
    it "should include AASM::Persistence::ActiveRecordPersistence::WriteState" do
      @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::WriteState)
    end    
    it "should include AASM::Persistence::ActiveRecordPersistence::WriteStateWithoutPersistence" do
      @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::WriteStateWithoutPersistence)
    end    
  end

  describe Fo, "class methods" do
    before(:each) do
      @klass = Fo
    end
    it_should_behave_like "aasm model"
    it "should include AASM::Persistence::ActiveRecordPersistence::ReadState" do
      @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::ReadState)
    end    
    it "should not include AASM::Persistence::ActiveRecordPersistence::WriteState" do
      @klass.included_modules.should_not be_include(AASM::Persistence::ActiveRecordPersistence::WriteState)
    end    
    it "should include AASM::Persistence::ActiveRecordPersistence::WriteStateWithoutPersistence" do
      @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::WriteStateWithoutPersistence)
    end    
  end

  describe Fum, "class methods" do
    before(:each) do
      @klass = Fum
    end
    it_should_behave_like "aasm model"
    it "should include AASM::Persistence::ActiveRecordPersistence::ReadState" do
      @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::ReadState)
    end    
    it "should include AASM::Persistence::ActiveRecordPersistence::WriteState" do
      @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::WriteState)
    end    
    it "should not include AASM::Persistence::ActiveRecordPersistence::WriteStateWithoutPersistence" do
      @klass.included_modules.should_not be_include(AASM::Persistence::ActiveRecordPersistence::WriteStateWithoutPersistence)
    end    
  end

  describe FooBar, "instance methods" do
    before(:each) do
      connection = mock(Connection, :columns => [])
      FooBar.stub!(:connection).and_return(connection)
    end

    it "should respond to aasm read state when not previously defined" do
      FooBar.new.should respond_to(:read_state)
    end

    it "should respond to aasm write state when not previously defined" do
      FooBar.new.should respond_to(:write_state)
    end

    it "should respond to aasm write state without persistence when not previously defined" do
      FooBar.new.should respond_to(:write_state_without_persistence)
    end

    it "should return the initial state when new and the aasm field is nil" do
      FooBar.new.current_state.should == :open
    end

    it "should return the aasm column when new and the aasm field is not nil" do
      foo = FooBar.new
      foo.state = "closed"
      foo.current_state.should == :closed
    end

    it "should return the aasm column when not new and the aasm_column is not nil" do
      foo = FooBar.new
      foo.stub!(:new_record?).and_return(false)
      foo.state = "state"
      foo.current_state.should == :state
    end

    it "should allow a nil state" do
      foo = FooBar.new
      foo.stub!(:new_record?).and_return(false)
      foo.state = nil
      foo.current_state.should be_nil
    end

    it "should have ensure_initial_state" do
      foo = FooBar.new
      foo.send :ensure_initial_state
    end

    it "should call ensure_initial_state on validation before create" do
      foo = FooBar.new
      foo.should_receive(:ensure_initial_state).and_return(true)
      foo.valid?
    end

    it "should call ensure_initial_state on validation before create" do
      foo = FooBar.new
      foo.stub!(:new_record?).and_return(false)
      foo.should_not_receive(:ensure_initial_state)
      foo.valid?
    end
    
  end

  describe 'Beavers' do
    it "should have the same states as it's parent" do
      Beaver.states.should == June.states
    end
    
    it "should have the same events as it's parent" do
      Beaver.events.should == June.events
    end
    
    it "should have the same column as it's parent" do
      Beaver.state_column.should == :status
    end
  end
  

  # TODO: figure out how to test ActiveRecord reload! without a database

rescue LoadError => e
  if e.message == "no such file to load -- active_record"
    puts "You must install active record to run this spec.  Install with sudo gem install activerecord"
  else
    raise
  end
end
