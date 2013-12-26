module ObjectifiedSessions
  class FieldDefinition
    class << self
      def normalize_name(name)
        unless name.kind_of?(String) || name.kind_of?(Symbol)
          raise ArgumentError, "A field name must be a String or Symbol, not: #{name.inspect}"
        end

        name.to_s.strip.downcase.to_sym
      end
    end

    attr_reader :name, :storage_name

    def initialize(session_class, name, options = { })
      @session_class = session_class
      @name = self.class.normalize_name(name)
      process_options!(options)

      create_methods!
    end

    def storage_name
      @storage_name || name
    end

    def delete_data_with_storage_name?
      type == :retired
    end

    def allow_access_to_data?
      type == :normal
    end

    private
    attr_reader :type, :visibility

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

    def create_methods!
      return unless type == :normal

      fn = name
      dmm = @session_class._dynamic_methods_module

      dmm.define_method(name) do
        self[fn]
      end

      dmm.define_method("#{name}=") do |new_value|
        self[fn] = new_value
      end

      if visibility == :private
        dmm.send(:private, name, "#{name}=".to_sym)
      end
    end
  end
end
