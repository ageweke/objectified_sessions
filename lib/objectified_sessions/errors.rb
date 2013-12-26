module ObjectifiedSessions
  module Errors
    class Base < StandardError; end

    class CannotCreateSessionError < Base; end

    class NoSuchFieldError < Base
      attr_reader :session_class, :field_name

      def initialize(session_class, field_name)
        @session_class = session_class
        @field_name = field_name

        super("Class #{@session_class.name} has no field named #{@field_name.inspect}; its fields are: #{accessible_field_names.inspect}")
      end

      def accessible_field_names
        session_class.accessible_field_names
      end
    end

    class DuplicateFieldNameError < Base
      attr_reader :session_class, :field_name

      def initialize(session_class, field_name)
        @session_class = session_class
        @field_name = field_name

        super("Class #{@session_class.name} already has one field named #{@field_name.inspect}; you can't define another.")
      end
    end

    class DuplicateFieldStorageNameError < Base
      attr_reader :session_class, :original_field_name, :new_field_name, :storage_name

      def initialize(session_class, original_field_name, new_field_name, storage_name)
        @session_class = session_class
        @original_field_name = original_field_name
        @new_field_name = new_field_name
        @storage_name = storage_name

        super("Class #{@session_class.name} already has a field, #{@original_field_name.inspect}, with storage name #{@storage_name.inspect}; you can't define field #{@new_field_name.inspect} with that same storage name.")
      end
    end
  end
end
