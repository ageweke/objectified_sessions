require 'objectified_sessions'
require 'objectified_sessions/field_definition'
require 'objectified_sessions/errors'

module ObjectifiedSessions
  class Base
    def initialize(underlying_session)
      @_base_underlying_session = underlying_session
      _delete_unknown_fields_if_needed!
    end

    private
    def _objectified_sessions_underlying_session(create_if_needed)
      prefix = self.class.prefix

      if prefix
        out = @_base_underlying_session[prefix]

        if (! out) && create_if_needed
          @_base_underlying_session[prefix] = { }
          out = @_base_underlying_session[prefix]
        end

        out
      else
        @_base_underlying_session
      end
    end

    def _delete_unknown_fields_if_needed!
      if self.class.unknown_fields == :delete
        underlying = _objectified_sessions_underlying_session(false)

        if underlying
          unknown = underlying.keys.select do |k|
            field = self.class._field_with_storage_name(k)
            (! field) || field.retired?
          end
          underlying.delete(unknown) if unknown.length > 0
        end
      end
    end

    def [](field_name)
      field = self.class._ensure_has_field_named(field_name)

      underlying = _objectified_sessions_underlying_session(false)
      underlying[field.storage_name] if underlying
    end

    def []=(field_name, new_value)
      field = self.class._ensure_has_field_named(field_name)
      _objectified_sessions_underlying_session(true)[field.storage_name] = new_value
    end

    DYNAMIC_METHODS_MODULE_NAME = :ObjectifiedSessionsDynamicMethods

    class << self
      def field(name, options = { })
        @fields ||= { }
        @fields_by_storage_name ||= { }

        new_field = ObjectifiedSessions::FieldDefinition.new(self, name, options)

        if @fields[new_field.name]
          raise ObjectifiedSessions::Errors::DuplicateFieldNameError.new(self, new_field.name)
        end

        if @fields_by_storage_name[new_field.storage_name]
          raise ObjectifiedSessions::Errors::DuplicateFieldStorageNameError.new(self, @fields_by_storage_name[new_field.storage_name].name, new_field.name, new_field.storage_name)
        end

        @fields[new_field.name] = new_field
        @fields_by_storage_name[new_field.storage_name] = new_field
      end

      def retired(name, options = { })
        field(name, options.merge(:retired => true))
      end

      def prefix(new_prefix = nil)
        if new_prefix
          @prefix = if new_prefix then new_prefix.to_s.strip.downcase.to_sym else nil end
        else
          @prefix
        end
      end

      def unknown_fields(what_to_do = nil)
        if what_to_do == nil
          @unknown_fields ||= :preserve
        elsif [ :delete, :preserve ].include?(what_to_do)
          @unknown_fields = what_to_do
        else
          raise ArgumentError, "You must pass :delete or :preserve, not: #{what_to_do.inspect}"
        end
      end

      def all_field_names
        @fields.keys
      end

      def _field_named(name)
        name = ObjectifiedSessions::FieldDefinition.normalize_name(name)
        @fields[name]
      end

      def _field_with_storage_name(storage_name)
        storage_name = ObjectifiedSessions::FieldDefinition.normalize_name(storage_name)
        @fields_by_storage_name[storage_name]
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
