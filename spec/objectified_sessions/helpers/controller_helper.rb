module ObjectifiedSessions
  module Helpers
    module ControllerHelper
      def new_spec_controller_instance
        ::ObjectifiedSessions._reset_for_specs!

        klass = Class.new(::ActionController::Base)
        klass_name = "SpecController#{rand(1_000_000_000)}"
        ::Object.const_set(klass_name, klass)

        underlying_session = double("underlying_session")

        instance = klass.new
        allow(instance).to receive(:session).with().and_return(underlying_session)
        instance
      end

      def define_objsession_class(name = nil, &block)
        @objsession_class = Class.new(::ObjectifiedSessions::Base)
        @objsession_class.class_eval(&block)

        if name
          ::Object.send(:remove_const, name) if ::Object.const_defined?(name)
          ::Object.send(:const_set, name, @objsession_class)
        end

        ::ObjectifiedSessions.session_class = @objsession_class
      end

      def set_new_controller_instance
        @controller_instance = new_spec_controller_instance
        @controller_class = @controller_instance.class
        @controller_class_name = @controller_class.name
        @underlying_session = @controller_instance.session
      end

      def should_be_using_prefix(prefix, should_require_set = false)
        prefix_set = (! should_require_set)

        if should_require_set
          expect(@underlying_session).to receive(:[]=).once.with(prefix, { }) do
            prefix_set = true
          end
        end

        @prefixed_underlying_session = double("prefixed_underlying_session")
        allow(@underlying_session).to receive(:[]).with(prefix) do
          if prefix_set
            @prefixed_underlying_session
          else
            nil
          end
        end
      end
    end
  end
end
