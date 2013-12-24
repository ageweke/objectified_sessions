module ObjectifiedSessions
  class FieldDefinition
    attr_reader :name

    def initialize(session_class, name, options = { })
      @session_class = session_class
      @name = name.to_s.strip.downcase.to_sym
      @options = options

      create_methods!
    end

    private
    attr_reader :options

    def create_methods!
      fn = name
      dmm = @session_class._dynamic_methods_module

      dmm.define_method(name) do
        _objectified_sessions_underlying_session[fn]
      end

      dmm.define_method("#{name}=") do |new_value|
        _objectified_sessions_underlying_session[fn] = new_value
      end

      if options[:visibility] == :private
        dmm.send(:private, name, "#{name}=".to_sym)
      end
    end
  end
end
