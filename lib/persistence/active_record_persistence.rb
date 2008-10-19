module AASM
  module Persistence
    module ActiveRecordPersistence
      # This method:
      #
      # * extends the model with ClassMethods
      # * includes InstanceMethods
      #
      # Unless the corresponding methods are already defined, it includes
      # * ReadState
      # * WriteState
      # * WriteStateWithoutPersistence
      #
      # Adds
      #
      #   before_validation_on_create :ensure_initial_state
      #
      # As a result, it doesn't matter when you define your methods - the following 2 are equivalent
      #
      #   class Foo < ActiveRecord::Base
      #     def write_state(state)
      #       "bar"
      #     end
      #     include AASM
      #   end
      #
      #   class Foo < ActiveRecord::Base
      #     include AASM
      #     def write_state(state)
      #       "bar"
      #     end
      #   end
      #
      def self.included(base)
        base.extend AASM::Persistence::ActiveRecordPersistence::ClassMethods
        base.send(:include, AASM::Persistence::ActiveRecordPersistence::InstanceMethods)
        base.send(:include, AASM::Persistence::ActiveRecordPersistence::ReadState) unless base.method_defined?(:read_state)
        base.send(:include, AASM::Persistence::ActiveRecordPersistence::WriteState) unless base.method_defined?(:write_state)
        base.send(:include, AASM::Persistence::ActiveRecordPersistence::WriteStateWithoutPersistence) unless base.method_defined?(:write_state_without_persistence)
        
        if base.respond_to?(:named_scope)
          base.extend(AASM::Persistence::ActiveRecordPersistence::NamedScopeMethods)
          
          base.class_eval do
            class << self
              alias_method :state_without_named_scope, :state
              alias_method :state, :state_with_named_scope
            end
          end
        end
        
        base.before_validation_on_create :ensure_initial_state
      end

      module ClassMethods
        # Maps to the aasm_column in the database.  Deafults to "state".  You can write:
        #
        #   create_table :foos do |t|
        #     t.string :name
        #     t.string :state
        #   end
        #
        #   class Foo < ActiveRecord::Base
        #     include AASM
        #   end
        #
        # OR:
        #
        #   create_table :foos do |t|
        #     t.string :name
        #     t.string :status
        #   end
        #
        #   class Foo < ActiveRecord::Base
        #     include AASM
        #     state_column :status
        #   end
        #
        # This method is both a getter and a setter
        def state_column(column_name=nil)
          if column_name
            AASM::StateMachine[self].config.column = column_name.to_sym
            # @state_column = column_name.to_sym
          else
            AASM::StateMachine[self].config.column ||= :state
            # @state_column ||= :state
          end
          # @state_column
          AASM::StateMachine[self].config.column
        end

        def find_in_state(number, state, *args)
          with_state_scope state do
            find(number, *args)
          end
        end

        def count_in_state(state, *args)
          with_state_scope state do
            count(*args)
          end
        end

        def calculate_in_state(state, *args)
          with_state_scope state do
            calculate(*args)
          end
        end

        protected
        def with_state_scope(state)
          with_scope :find => {:conditions => ["#{table_name}.#{state_column} = ?", state.to_s]} do
            yield if block_given?
          end
        end
      end

      module InstanceMethods

        # Returns the current state of the object.  Respects reload and
        # any changes made to the state field directly
        # 
        # Internally just calls <tt>aasm_read_state</tt>
        #
        #   foo = Foo.find(1)
        #   foo.current_state # => :pending
        #   foo.state = "opened"
        #   foo.current_state # => :opened
        #   foo.close # => calls write_state_without_persistence
        #   foo.current_state # => :closed
        #   foo.reload
        #   foo.current_state # => :pending
        #
        def current_state
          @current_state = read_state
        end

        private
        
        # Ensures that if the state column is nil and the record is new
        # that the initial state gets populated before validation on create
        #
        #   foo = Foo.new
        #   foo.state # => nil
        #   foo.valid?
        #   foo.state # => "open" (where :open is the initial state)
        #
        #
        #   foo = Foo.find(:first)
        #   foo.state # => 1
        #   foo.state = nil
        #   foo.valid?
        #   foo.state # => nil
        #
        def ensure_initial_state
          send("#{self.class.state_column}=", self.current_state.to_s)
        end

      end

      module WriteStateWithoutPersistence
        # Writes <tt>state</tt> to the state column, but does not persist it to the database
        # 
        #   foo = Foo.find(1)
        #   foo.current_state # => :opened
        #   foo.close
        #   foo.current_state # => :closed
        #   Foo.find(1).current_state # => :opened
        #   foo.save
        #   foo.current_state # => :closed
        #   Foo.find(1).current_state # => :closed
        #
        # NOTE: intended to be called from an event
        def write_state_without_persistence(state)
          write_attribute(self.class.state_column, state.to_s)
        end
      end

      module WriteState
        # Writes <tt>state</tt> to the state column and persists it to the database
        # using update_attribute (which bypasses validation)
        # 
        #   foo = Foo.find(1)
        #   foo.current_state # => :opened
        #   foo.close!
        #   foo.current_state # => :closed
        #   Foo.find(1).aasm_current_state # => :closed
        #
        # NOTE: intended to be called from an event
        def write_state(state)
          old_value = read_attribute(self.class.state_column)
          write_attribute(self.class.state_column, state.to_s)
          
          unless self.save
            write_attribute(self.class.state_column, old_value)
            return false
          end
          
          true
        end
      end

      module ReadState

        # Returns the value of the aasm_column - called from <tt>aasm_current_state</tt>
        #
        # If it's a new record, and the aasm state column is blank it returns the initial state:
        #
        #   class Foo < ActiveRecord::Base
        #     include AASM
        #     column :status
        #     state :opened
        #     state :closed
        #   end
        # 
        #   foo = Foo.new
        #   foo.current_state # => :opened
        #   foo.close
        #   foo.current_state # => :closed
        #   
        #   foo = Foo.find(1)
        #   foo.current_state # => :opened
        #   foo.state = nil
        #   foo.current_state # => nil
        # 
        # NOTE: intended to be called from an event
        #
        # This allows for nil aasm states - be sure to add validation to your model
        def read_state
          if new_record?
            send(self.class.state_column).blank? ? self.class.initial_state : send(self.class.state_column).to_sym
          else
            send(self.class.state_column).nil? ? nil : send(self.class.state_column).to_sym
          end
        end
      end

      module NamedScopeMethods
        def state_with_named_scope name, options = {}
          state_without_named_scope name, options
          self.named_scope name, :conditions => {self.state_column => name.to_s} unless self.scopes.include?(name)
        end       
      end
    end
  end
end
