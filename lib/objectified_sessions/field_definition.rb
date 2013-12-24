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

    attr_reader :name

    def initialize(session_class, name, options = { })
      @session_class = session_class
      @name = self.class.normalize_name(name)
      @options = options

      validate_options!

      create_methods!
    end

    def storage_name
      @storage_name || name
    end

    def retired?
      options[:retired]
    end

    private
    attr_reader :options

    def validate_options!
      if options[:storage]
        @storage_name = self.class.normalize_name(options[:storage])
      end
    end

    def create_methods!
      fn = name
      dmm = @session_class._dynamic_methods_module

      dmm.define_method(name) do
        self[fn]
      end

      dmm.define_method("#{name}=") do |new_value|
        self[fn] = new_value
      end

      if options[:visibility] == :private
        dmm.send(:private, name, "#{name}=".to_sym)
      end
    end
  end
end
