require File.join(File.dirname(__FILE__), 'event')
require File.join(File.dirname(__FILE__), 'state')
require File.join(File.dirname(__FILE__), 'state_machine')
require File.join(File.dirname(__FILE__), 'persistence')

module AASM
  def self.Version
    '2.0.2'
  end

  class InvalidTransition < RuntimeError
  end
  
  def self.included(base) #:nodoc:
    # TODO - need to ensure that a machine is being created because
    # AASM was either included or arrived at via inheritance.  It
    # cannot be both.
    base.extend AASM::ClassMethods
    AASM::Persistence.set_persistence(base)
    AASM::StateMachine[base] = AASM::StateMachine.new('')

    base.class_eval do
      def base.inherited(klass)
        AASM::StateMachine[klass] = AASM::StateMachine[self].dup
      end
    end
  end

  module ClassMethods
    def initial_state(set_state=nil)
      if set_state
        AASM::StateMachine[self].initial_state = set_state
      else
        AASM::StateMachine[self].initial_state
      end
    end
    
    def initial_state=(state)
      AASM::StateMachine[self].initial_state = state
    end
    
    def state(name, options={})
      sm = AASM::StateMachine[self]
      sm.create_state(name, options)
      sm.initial_state = name unless sm.initial_state

      define_method("#{name.to_s}?") do
        current_state == name
      end
    end
    
    def event(name, options = {}, &block)
      sm = AASM::StateMachine[self]
      
      unless sm.events.has_key?(name)
        sm.events[name] = AASM::SupportingClasses::Event.new(name, options, &block)
      end

      define_method("#{name.to_s}!") do |*args|
        fire_event(name, true, *args)
      end

      define_method("#{name.to_s}") do |*args|
        fire_event(name, false, *args)
      end
    end

    def states
      AASM::StateMachine[self].states
    end

    def events
      AASM::StateMachine[self].events
    end
    
    def states_for_select
      AASM::StateMachine[self].states.map { |state| state.for_select }
    end
    
  end

  # Instance methods
  def current_state
    return @current_state if @current_state

    if self.respond_to?(:read_state) || self.private_methods.include?('read_state')
      @current_state = read_state
    end
    return @current_state if @current_state
    self.class.initial_state
  end

  def events_for_current_state
    events_for_state(current_state)
  end

  def events_for_state(state)
    events = self.class.events.values.select {|event| event.transitions_from_state?(state) }
    events.map {|event| event.name}
  end

  private
  def set_current_state_with_persistence(state)
    save_success = true
    if self.respond_to?(:write_state) || self.private_methods.include?('write_state')
      save_success = write_state(state)
    end
    self.current_state = state if save_success

    save_success
  end

  def current_state=(state)
    if self.respond_to?(:write_state_without_persistence) || self.private_methods.include?('write_state_without_persistence')
      write_state_without_persistence(state)
    end
    @current_state = state
  end

  def state_object_for_state(name)
    self.class.states.find {|s| s == name}
  end

  def fire_event(name, persist, *args)
    state_object_for_state(current_state).call_action(:exit, self)

    new_state = self.class.events[name].fire(self, *args)
    
    unless new_state.nil?
      state_object_for_state(new_state).call_action(:enter, self)
      
      persist_successful = true
      if persist
        persist_successful = set_current_state_with_persistence(new_state)
        self.class.events[name].execute_success_callback(self) if persist_successful
      else
        self.current_state = new_state
      end

      if persist_successful 
        self.event_fired(self.current_state, new_state) if self.respond_to?(:event_fired)
      else
        self.event_failed(name) if self.respond_to?(:event_failed)
      end

      persist_successful
    else
      if self.respond_to?(:event_failed)
        self.event_failed(name)
      end
      
      false
    end
  end
end
