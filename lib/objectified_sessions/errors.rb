module ObjectifiedSessions
  module Errors
    class Base < StandardError; end

    class CannotCreateSessionError < Base; end

    class NoSuchFieldError < Base
      attr_reader :session_class, :field_name

      def initialize(session_class, field_name)
        @session_class = session_class
        @field_name = field_name

        super("Class #{@session_class.name} has no field named #{@field_name.inspect}; its fields are: #{all_field_names.inspect}")
      end

      def all_field_names
        session_class.all_field_names
      end
    end
  end
end
