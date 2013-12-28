require 'objectified_sessions'
require 'objectified_sessions/field_definition'
require 'objectified_sessions/errors'

module ObjectifiedSessions
  # ObjectifiedSessions::Base is the base class for all objectified sessions -- in other words, all classes that
  # actually implement an objectified session must inherit from this class. It therefore contains the methods that
  # allow you to define new fields, set various options (like #unknown_fields and #default_visibility), and so on.
  #
  # Most functionality here is actually implemented on the class itself (the <tt>class << self</tt> block below), as
  # most of the functionality has to do with defining which fields exist, how they should behave, and so on.
  # Behavior for an actual instance is smaller, and largely limited to reading and writing data from fields, as
  # most such access comes through dynamically-generated methods via the class.
  class Base
    # Creates a new instance. +underlying_session+ is the Rails session object -- _i.e._, whatever is returned by
    # calling #session in a controller. (The actual class of this object varies among Rails versions, but its
    # behavior is identical for our purposes.)
    #
    # This method also takes care of calling #_delete_unknown_fields_if_needed!, which, as its name suggests, is
    # responsible for deleting any data that does not map to any known fields.
    def initialize(underlying_session)
      @_base_underlying_session = underlying_session
      _delete_unknown_fields_if_needed!
    end

    private
    # This method returns the 'true' underlying session we should use. Typically this is nothing more than
    # +@_base_underlying_session+ -- the argument passed in to our constructor -- but, if a prefix is set, this is
    # responsible for fetching the "sub-session" Hash we should use to store all our data, instead.
    #
    # +create_if_needed+ should be set to +true+ if, when calling this method, we should create the prefixed
    # "sub-session" Hash if it's not present. If +false+, this method can return +nil+, if there is no
    # prefixed sub-session. We allow this parameter to make sure we don't bind an empty Hash to our prefix if there's
    # nothing to store in it anyway.
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

    # Takes care of deleting any unknown fields, if unknown_fields == :delete.
    def _delete_unknown_fields_if_needed!
      if self.class.unknown_fields == :delete
        underlying = _objectified_sessions_underlying_session(false)

        if underlying # can be nil, if there's a prefix and nothing stored in it yet
          # Find all keys that either don't map to a field, or map to a field with #delete_data_with_storage_name? =>
          # true -- that is, retired fields.
          unknown = underlying.keys.select do |k|
            field = self.class._field_with_storage_name(k)
            (! field) || field.delete_data_with_storage_name?
          end

          underlying.delete(unknown) if unknown.length > 0
        end
      end
    end

    # Returns the current value for the field with the given name. +field_name+ can be specified as a String or a
    # Symbol. Returns nil if nothing has been set yet.
    #
    # If passed a field name that hasn't been defined on this class, raises
    # ObjectifiedSessions::Errors::NoSuchFieldError.
    def [](field_name)
      field = self.class._ensure_has_field_named(field_name)

      underlying = _objectified_sessions_underlying_session(false)
      underlying[field.storage_name] if underlying
    end

    # Stores a new value to the given field. +field_name+ can be specified as a String or a Symbol. If passed +nil+,
    # will store +nil+ to the underlying session, which deletes the given key from the session entirely.
    #
    # If passed a field name that hasn't been defined on this class, raises
    # ObjectifiedSessions::Errors::NoSuchFieldError.
    def []=(field_name, new_value)
      field = self.class._ensure_has_field_named(field_name)
      _objectified_sessions_underlying_session(true)[field.storage_name] = new_value
      new_value
    end

    DYNAMIC_METHODS_MODULE_NAME = :ObjectifiedSessionsDynamicMethods

    class << self
      # Defines a new field. +name+ is the name of the field, specified as either a String or a Symbol. +options+ can
      # contain:
      #
      # [:visibility] If +:private+, methods generated for this field will be marked as private, meaning they can only
      #               be accessed from inside the objectified-session class itself. If +:public+, methods will be
      #               marked as public, making them accessible from anywhere. If omitted, the class's
      #               #default_visibility will be used (which itself defaults to +:public+).
      # [:storage] If specified, this field will be stored in the session under the given String or Symbol (which will
      #            be converted to a String before being used). If not specified, data will be stored under the name of
      #            the field (converted to a String), instead.
      def field(name, options = { })
        @fields ||= { }
        @fields_by_storage_name ||= { }

        # Compute our effective options.
        options = { :visibility => default_visibility }.merge(options)
        options[:type] ||= :normal

        # Create a new FieldDefinition instance.
        new_field = ObjectifiedSessions::FieldDefinition.new(self, name, options)

        # Check for a conflict with the field name.
        if @fields[new_field.name]
          raise ObjectifiedSessions::Errors::DuplicateFieldNameError.new(self, new_field.name)
        end

        # Check for a conflict with the storage name.
        if @fields_by_storage_name[new_field.storage_name]
          raise ObjectifiedSessions::Errors::DuplicateFieldStorageNameError.new(self, @fields_by_storage_name[new_field.storage_name].name, new_field.name, new_field.storage_name)
        end

        @fields[new_field.name] = new_field
        @fields_by_storage_name[new_field.storage_name] = new_field
      end

      def retired(name, options = { })
        field(name, options.merge(:type => :retired))
      end

      def inactive(name, options = { })
        field(name, options.merge(:type => :inactive))
      end

      def default_visibility(new_visibility = nil)
        if new_visibility
          if [ :public, :private ].include?(new_visibility)
            @default_visibility = new_visibility
          else
            raise ArgumentError, "Invalid default visibility: #{new_visibility.inspect}; must be :public or :private"
          end
        else
          @default_visibility ||= :public
        end
      end

      def prefix(new_prefix = nil)
        if new_prefix.kind_of?(String) || new_prefix.kind_of?(Symbol)
          @prefix = if new_prefix then new_prefix.to_s.strip else nil end
        elsif new_prefix
          raise ArgumentError, "Invalid prefix; must be a String or Symbol: #{new_prefix.inspect}"
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

      def accessible_field_names
        if @fields
          @fields.values.select { |f| f.allow_access_to_data? }.map(&:name)
        else
          [ ]
        end
      end

      def _field_named(name)
        name = ObjectifiedSessions::FieldDefinition.normalize_name(name)
        @fields[name]
      end

      def _field_with_storage_name(storage_name)
        storage_name = ObjectifiedSessions::FieldDefinition.normalize_name(storage_name).to_s
        @fields_by_storage_name[storage_name]
      end

      def _ensure_has_field_named(name)
        out = _field_named(name)
        out = nil if out && (! out.allow_access_to_data?)
        out || (raise ObjectifiedSessions::Errors::NoSuchFieldError.new(self, name))
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
