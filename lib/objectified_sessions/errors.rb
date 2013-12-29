module ObjectifiedSessions
  # This module contains definitions of errors for ObjectifiedSessions.
  module Errors
    # The base class from which all ObjectifiedSessions errors descend.
    class Base < StandardError; end

    # Raised when we cannot create the ObjectifiedSessions subclass, when someone calls #objsession; this usually means
    # either the subclass hasn't been defined, or its constructor, for some reason, raised an error.
    class CannotCreateSessionError < Base; end

    # Raised when you try to read or write a field (via hash-indexing) that simply isn't defined on your objectified
    # session.
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

    # Raised when you try to define a field that has the same name as a previously-defined field.
    class DuplicateFieldNameError < Base
      attr_reader :session_class, :field_name

      def initialize(session_class, field_name)
        @session_class = session_class
        @field_name = field_name

        super("Class #{@session_class.name} already has one field named #{@field_name.inspect}; you can't define another.")
      end
    end

    # Raised when you try to define a field that has a different name, but the same storage name, as a previously-defined
    # field.
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
