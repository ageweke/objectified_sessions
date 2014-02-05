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

    # A convenient alias for accessible_field_names, so you don't have to go through the class.
    def field_names
      self.class.accessible_field_names
    end

    # Returns the (possibly empty) set of all field names that actually have data present.
    def keys
      field_names.select { |f| self[f] != nil }
    end

    # Returns a nice, pretty string of the current set of values for this session. We abbreviate long values by default,
    # so that we don't return some absurdly-long string.
    def to_s(abbreviate = true)
      out = "<#{self.class.name}: "

      out << keys.sort_by(&:to_s).map do |k|
        s = self[k].inspect
        s = s[0..36] + "..." if abbreviate && s.length > 40
        "#{k}: #{s}"
      end.join(", ")

      out << ">"
      out
    end

    # Make #inspect do the same as #to_s, so we also get this in debugging output.
    def inspect(abbreviate = true)
      to_s(abbreviate)
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
      validate_new_value_type!(new_value)
      _objectified_sessions_underlying_session(true)[field.storage_name] = new_value
      new_value
    end

    # Validates that a new value being assigned to a field is acceptable, according to whatever #allowed_value_types
    # setting you've set on this class. Does nothing if the data is valid; raises ArgumentError if it's invalid.
    def validate_new_value_type!(new_value)
      send("validate_new_value_type_for_#{self.class.allowed_value_types}!", new_value)
    end

    # Validates that a new value being assigned to a field is acceptable, according to the :anything
    # #allowed_value_types setting. This allows storing anything, so this method is a no-op.
    def validate_new_value_type_for_anything!(new_value)
      # ok
    end

    # Validates that a new value being assigned to a field is acceptable, according to the :primitive
    # #allowed_value_types setting. This raises an exception if passed anything but a simple scalar.
    def validate_new_value_type_for_primitive!(new_value)
      case new_value
      when String, Symbol, Numeric, Time, true, false, nil then true
      else
        raise ArgumentError, "You've asked your ObjectifiedSession to only allow values of scalar types, but you're trying to store this: #{new_value.inspect}"
      end
    end

    # Validates that a new value being assigned to a field is acceptable, according to the :primitive_and_compound
    # #allowed_value_types setting. This does recursive examination of Arrays and Hashes. Raises an ArgumentError
    # if there's an invalid value present.
    def validate_new_value_type_for_primitive_and_compound!(new_value)
      case new_value
      when String, Symbol, Numeric, Time, true, false, nil then true
      when Array then
        new_value.each { |x| validate_new_value_type_for_primitive_and_compound!(x) }
      when Hash then
        new_value.each do |k,v|
          validate_new_value_type_for_primitive_and_compound!(k)
          validate_new_value_type_for_primitive_and_compound!(v)
        end
      else
        raise ArgumentError, "You've asked your ObjectifiedSession to only allow values of scalar types, plus Arrays and Hashes, but you're trying to store this (possibly nested): #{new_value.inspect}"
      end
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

      # Defines a retired field. A retired field is really nothing more than a marker indicating that you _used_ to
      # have a field with a given name (and, potentially, storage alias); you can't access its data, and, if
      # you've set <tt>unknown_fields :delete</tt>, any data _will_ be deleted.
      #
      # So, what's the point? You will still get an error if you try to define another field with the same name, or
      # storage alias. If you re-use a field, then, especially if you're using Rails' default CookieStore, you
      # can run into awful problems where data from some previous usage is interpreted as being valid data for the new
      # usage. Instead of simply removing fields when you're done with them, make them retired (and move them to the
      # bottom of the class, if you want, for better readability); this will have the same effect as removing them,
      # but will keep you from accidentally reusing them in the future.
      #
      # +name+ is the name of the field; the only valid option for +options+ is +:storage+. (+:visibility+ is accepted
      # but ignored, since no methods are generated for retired fields.)
      def retired(name, options = { })
        field(name, options.merge(:type => :retired))
      end

      # Defines an inactive field. An inactive field is identical to a retired field, except that, if you've set
      # <tt>unknown_fields :delete</tt>, data from an inactive field will _not_ be deleted. You can use it as a way of
      # retiring a field that you no longer want to use from code, but whose data you still want preserved. (If you
      # have not set <tt>unknown_fields :delete</tt>, then it behaves identically to a retired field.)
      #
      # +name+ is the name of the field; the only valid option for +options+ is +:storage+. (+:visibility+ is accepted
      # but ignored, since no methods are generated for inactive fields.)
      def inactive(name, options = { })
        field(name, options.merge(:type => :inactive))
      end

      # Sets the default visibility of new fields on this class. This is ordinarily +:public+, meaning fields will
      # generate accessor methods (_e.g._, +#foo+ and +#foo=+) that are public unless you explicitly say
      # <tt>:visibility => :private</tt> in the field definition. However, you can change it to +:private+, meaning
      # fields will be private unless you explicitly specify <tt>:visibility => :public</tt>.
      #
      # If called without an argument, returns the current default visibility for fields on this class.
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

      ALLOWED_ALLOWED_VALUE_TYPES = %w{anything primitive_and_compound primitive}.map { |x| x.to_sym }

      # Sets the allowed value types on this class, or returns the current setting if no argument is supplied.
      # The valid settings are:
      #
      # [:anything] All values are allowed, including arbitrary Ruby objects.
      # [:primitive] Only primitive, simple scalars are allowed: nil, true, false, Strings, Symbols, Numerics (including
      #              both integer and floating-point numbers), and Times. Arrays and Hashes are not allowed.
      # [:primitive_and_compound] All primitive scalars, plus Arrays and Hashes composed entirely of primitive
      #                           scalars, plus other Arrays and Hashes, are allowed.
      def allowed_value_types(allowed = nil)
        if allowed
          allowed = allowed.to_s.strip.downcase.to_sym
          raise ArgumentError, "Invalid value for allowed_value_types: #{allowed.inspect}; we allow: #{ALLOWED_ALLOWED_VALUE_TYPES.inspect}" unless ALLOWED_ALLOWED_VALUE_TYPES.include?(allowed)

          @allowed_value_types = allowed
        end

        @allowed_value_types ||= :anything
      end

      # Sets the prefix. If a prefix is set, then all field data is taken from (and stored into) a Hash bound to this
      # prefix within the session, rather than directly in the session; this segregates all your ObjectifiedSession
      # data from other usage of the session. This is not generally necessary, but can be useful in certain situations.
      # Note that setting a prefix affects _all_ fields, not just those defined after it's set; the prefix is global
      # to your objectified session, and you can only have a single prefix at once.
      #
      # Perhaps obvious, but changing the prefix will effectively cause all your objectified-session data to disappear,
      # as it'll be stored under a different key. Choose once, at the beginning.
      #
      # If called with no arguments, returns the current prefix.
      def prefix(new_prefix = :__none_specified)
        if new_prefix == :__none_specified
          @prefix
        elsif new_prefix.kind_of?(String) || new_prefix.kind_of?(Symbol) || new_prefix == nil
          @prefix = if new_prefix then new_prefix.to_s.strip else nil end
        else
          raise ArgumentError, "Invalid prefix; must be a String or Symbol: #{new_prefix.inspect}"
        end
      end

      # Sets what to do with unknown fields. With +:preserve+, the default setting, any data residing under keys that
      # aren't defined as a field will simply be preserved, even as it's inaccessible. With +:delete+, any data
      # residing under keys that aren't defined as a field will be *deleted* when your objectified session class is
      # instantiated. Obviously, be careful if you set this to +:delete+; if you're using traditional session access
      # anywhere else in code, and you don't duplicate its use as a field in your objectified session, really bad things
      # will happen as the objectified session removes keys being used by other parts of the code. But it's a very nice
      # way to keep your session tidy, too.
      def unknown_fields(what_to_do = nil)
        if what_to_do == nil
          @unknown_fields ||= :preserve
        elsif [ :delete, :preserve ].include?(what_to_do)
          @unknown_fields = what_to_do
        else
          raise ArgumentError, "You must pass :delete or :preserve, not: #{what_to_do.inspect}"
        end
      end

      # What are the names of all fields that are accessible -- that is, whose data can be accessed? This returns an
      # array of field names, not storage names; retired fields and inactive fields don't allow access to their data,
      # so they won't be included.
      def accessible_field_names
        if @fields
          @fields.values.select { |f| f.allow_access_to_data? }.map(&:name)
        else
          [ ]
        end
      end

      # Returns the FieldDefinition object with the given name, if any.
      def _field_named(name)
        name = ObjectifiedSessions::FieldDefinition.normalize_name(name)
        @fields[name]
      end

      # Returns the FieldDefinition object that stores its data under the given key, if any.
      def _field_with_storage_name(storage_name)
        storage_name = ObjectifiedSessions::FieldDefinition.normalize_name(storage_name).to_s
        @fields_by_storage_name[storage_name]
      end

      # If this class doesn't have an active field (not retired or inactive) with the given name, raises
      # ObjectifiedSessions::Errors::NoSuchFieldError. This is used as a guard to make sure we don't try to retrieve
      # data that hasn't been defined as a field.
      def _ensure_has_field_named(name)
        out = _field_named(name)
        out = nil if out && (! out.allow_access_to_data?)
        out || (raise ObjectifiedSessions::Errors::NoSuchFieldError.new(self, name))
      end

      # Returns the dynamic-methods module. The dynamic-methods module is a new Module that is automatically included
      # into the objectified-sessions class and given a reasonable name; it also has #define_method and #private made
      # into public methods, so that it's easy to define methods on it.
      #
      # The dynamic-methods module is where we define all the accessor methods that #field generates. We do this instead
      # of defining them directly on this class so that you can override them, and #super will still work properly.
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
