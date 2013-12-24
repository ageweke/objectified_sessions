module ObjectifiedSessions
  module Helpers
    module ControllerHelper
      def new_spec_controller_instance
        klass = Class.new(::ActionController::Base)
        klass_name = "SpecController#{rand(1_000_000_000)}"
        ::Object.const_set(klass_name, klass)

        underlying_session = double("underlying_session")

        instance = klass.new
        allow(instance).to receive(:session).with().and_return(underlying_session)
        instance
      end

      def define_objsession_class(&block)
        @objsession_class = Class.new(::ObjectifiedSessions::Base)
        @objsession_class.class_eval(&block)

        ::ObjectifiedSessions.session_class = @objsession_class
      end

      def set_new_controller_instance
        @controller_instance = new_spec_controller_instance
        @controller_class = @controller_instance.class
        @controller_class_name = @controller_class.name
        @underlying_session = @controller_instance.session
      end
    end
  end
end
