require "action_controller"
require "objectified_sessions/version"
require "objectified_sessions/base"
require "objectified_session_generator"

module ObjectifiedSessions
  DEFAULT_OBJSESSION_CLASS_NAME = "Objsession"

  class << self
    def _create_new_objsession(underlying_session)
      klass = _session_class_object
      out = nil

      begin
        out = klass.new(underlying_session)
      rescue Exception => e
        raise ObjectifiedSessions::Errors::CannotCreateSessionError, %{When objectified_sessions went to create a new instance of the session class, it
got an exception from the call to #{klass.name}.new:

(#{e.class.name}) #{e.message}
    #{e.backtrace.join("\n    ")}}
      end

      unless out.kind_of?(::ObjectifiedSessions::Base)
        raise ObjectifiedSessions::Errors::CannotCreateSessionError, %{When objectified_sessions went to create a new instance of the session class, it
got back an object that isn't an instance of a subclass of ObjectifiedSessions::Base.

It got back an instance of #{out.class.name}:
#{out.inspect}}
      end

      out
    end

    def session_class
      @session_class ||= DEFAULT_OBJSESSION_CLASS_NAME
    end

    def session_class=(target_class)
      unless [ String, Symbol, Class ].include?(target_class.class)
        raise ArgumentError, "You must pass a String, Symbol, or Class, not: #{target_class.inspect}"
      end

      if target_class.kind_of?(String) || target_class.kind_of?(Symbol)
        target_class = target_class.to_s.camelize
      end

      @session_class = target_class
    end

    private
    def _session_class_object
      klass = session_class

      unless klass.kind_of?(Class)
        path = nil
        load_error = nil

        begin
          path = klass.underscore

          begin
            require path
          rescue LoadError => le
            load_error = le
          end

          klass = klass.constantize
        rescue NameError => ne
          message = nil

          if klass.to_s == DEFAULT_OBJSESSION_CLASS_NAME.to_s
            message = %{Before using objectified_sessions, you need to define the class that implements your
objectfied session. By default, this is named #{klass.inspect}; simply create a class of
that name, in the appropriate place in your project (e.g., lib/objsession.rb). You can
run 'rails generate objectified_session' to do this for you.

Alternatively, tell objectified_sessions to use a particular class, by saying

  ObjectifiedSessions.session_class = <class name>

somewhere in your config/application.rb, or some similar initialization code.}
          else
            message = %{When objectified_sessions went to create a new instance of the session class, it
couldn't resolve the actual class. You specified #{klass.inspect} as the session class,
but, when we called #constantize on it, we got the following NameError:

(#{ne.class.name}) #{ne}}
          end

          if load_error
            message += %{

(When we tried to require the file presumably containing this class (with 'require #{path.inspect}'),
we got a LoadError: #{load_error.message}. This may not be an issue, if you have this class defined elsewhere; in
that case, you can simply ignore the error. But it may also indicate that the file you've defined this class in,
if any, isn't on the load path.)}
          end

          raise NameError, message
        end
      end

      klass
    end
  end
end

class ActionController::Base
  def objsession
    @_objsession ||= ::ObjectifiedSessions::_create_new_objsession(session)
  end
end
