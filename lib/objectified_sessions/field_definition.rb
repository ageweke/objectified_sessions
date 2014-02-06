module ObjectifiedSessions
  # A FieldDefinition represents, well, the definition of a single field against a single class (which must be a
  # descendant of ObjectifiedSessions::Base). It knows how to respond to a few questions, and is responsible for
  # creating appropriate delegated methods in its owning class's +_dynamic_methods_module+.
  class FieldDefinition
    class << self
      # Normalizes the name of a field. We use this method to make sure we don't get confused between Strings and
      # Symbols, and so on.
      def normalize_name(name)
        unless name.kind_of?(String) || name.kind_of?(Symbol)
          raise ArgumentError, "A field name must be a String or Symbol, not: #{name.inspect}"
        end

        name.to_s.strip.to_sym
      end
    end

    attr_reader :name, :storage_name

    # Creates a new instance. +session_class+ must be the Class that you're using as your objectified-session class --
    # _i.e._, a subclass of ObjectifiedSessions::Base. +name+ is the name of the field. +options+ are the options for
    # the field:
    #
    # [:type] Required; must be one of: +:normal+, +:retired+, or +:inactive+, each corresponding to the field type
    #         documented in ObjectifiedSessions::Base.
    # [:storage] If present, this field will use the specified string as the key under which it should be stored; if
    #            not present, the name will be used instead.
    # [:visibility] Required; must be +:private+ or +:public+. Methods created on the #_dynamic_methods_module on
    #               the base class will be of this visibility.
    def initialize(session_class, name, options = { })
      raise ArgumentError, "Session class must be a Class, not: #{session_class.inspect}" unless session_class.kind_of?(Class)

      @session_class = session_class
      @name = self.class.normalize_name(name)
      process_options!(options)

      create_methods!
    end

    # Allow field comparison. We do this when you define a field that has the exact same name or storage name as another
    # field -- we allow it if (and only if) they are identical in every other way.
    def ==(other)
      return false unless other.kind_of?(ObjectifiedSessions::FieldDefinition)
      session_class == other.send(:session_class) && name == other.name && storage_name == other.storage_name &&
        type == other.send(:type) && visibility == other.send(:visibility)
    end

    # Make sure eql? works the same as ==.
    def eql?(other)
      self == other
    end

    # Returns the key under which this field should read and write its data. This will be its name, unless a
    # +:storage+ option was passed to the constructor, in which case it will be that value, instead.
    def storage_name
      @storage_name || name
    end

    # If someone has set <tt>unknown_fields :delete</tt> on the base class, should we delete data with this field's
    # #storage_name anyway? This is true only for retired fields.
    def delete_data_with_storage_name?
      type == :retired
    end

    # Should we allow users to access the data in this field? Retired and inactive fields don't allow access to their
    # data.
    def allow_access_to_data?
      type == :normal
    end

    private
    attr_reader :type, :visibility, :session_class

    # Process the options passed in; this validates them, and sets +@type+, +@visibility+, and +@storage_name+
    # appropriately.
    def process_options!(options)
      options.assert_valid_keys(:storage, :type, :visibility)

      case options[:storage]
      when nil, String, Symbol then nil
      else raise ArgumentError, "Invalid value for :storage: #{options[:storage].inspect}"
      end

      if options[:storage]
        @storage_name = self.class.normalize_name(options[:storage]).to_s
      else
        @storage_name = self.name.to_s
      end

      raise ArgumentError, "Invalid value for :type: #{options[:type].inspect}" unless [ :normal, :inactive, :retired ].include?(options[:type])
      @type = options[:type]

      raise ArgumentError, "Invalid value for :visibility: #{options[:visibility].inspect}" unless [ :public, :private ].include?(options[:visibility])
      @visibility = options[:visibility]
    end

    # Creates methods on the dynamic-methods module, as appropriate.
    def create_methods!
      return unless type == :normal

      fn = name
      dmm = session_class._dynamic_methods_module
      mn = name.to_s.downcase

      dmm.define_method(mn) do
        self[fn]
      end

      dmm.define_method("#{mn}=") do |new_value|
        self[fn] = new_value
      end

      if visibility == :private
        dmm.send(:private, mn, "#{mn}=".to_sym)
      end
    end
  end
end
