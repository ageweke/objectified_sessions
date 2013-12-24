require 'objectified_sessions'
require 'objectified_sessions/field_definition'
require 'objectified_sessions/errors'

module ObjectifiedSessions
  class Base
    def initialize(underlying_session)
      @_objectified_sessions_underlying_session = underlying_session
    end

    private
    def _objectified_sessions_underlying_session
      @_objectified_sessions_underlying_session
    end

    def [](field_name)
      self.class._ensure_has_field_named(field_name)
      _objectified_sessions_underlying_session[field_name]
    end

    def []=(field_name, new_value)
      self.class._ensure_has_field_named(field_name)
      _objectified_sessions_underlying_session[field_name] = new_value
    end

    DYNAMIC_METHODS_MODULE_NAME = :ObjectifiedSessionsDynamicMethods

    class << self
      def field(name, options = { })
        @fields ||= { }

        new_field = ObjectifiedSessions::FieldDefinition.new(self, name, options)
        @fields[new_field.name] = new_field
      end

      def all_field_names
        @fields.keys
      end

      def _field_named(name)
        name = ObjectifiedSessions::FieldDefinition.normalize_name(name)
        @fields[name]
      end

      def _ensure_has_field_named(name)
        _field_named(name) || (raise ObjectifiedSessions::Errors::NoSuchFieldError.new(self, name))
      end

      def _dynamic_methods_module
        @_dynamic_methods_module ||= begin
          out = Module.new do
            class << self
              public :define_method, :private
            end
          end

          remove_const(DYNAMIC_METHODS_MODULE_NAME) if const_defined?(DYNAMIC_METHODS_MODULE_NAME)
          const_set(DYNAMIC_METHODS_MODULE_NAME, out)

          include out
          out
        end
      end
    end
  end
end
