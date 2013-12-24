require "action_controller"
require "objectified_sessions/version"
require "objectified_sessions/base"

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
        raise ""
      end

      out
    end

    def _session_class_object
      klass = session_class

      unless klass.kind_of?(Class)
        begin
          klass = klass.constantize
        rescue NameError => ne
          if klass.to_s == DEFAULT_OBJSESSION_CLASS_NAME.to_s
            raise NameError, %{Before using objectified_sessions, you need to define the class that implements your
objectfied session. By default, this is named #{klass.inspect}; simply create a class of
that name, in the appropriate place in your project (e.g., lib/objsession.rb). You can
run 'rails generate objectified_session' to do this for you.

Alternatively, tell objectified_sessions to use a particular class, by saying

  ObjectifiedSessions.session_class = <class name>

somewhere in your config/application.rb, or some similar initialization code.}
          else
            raise NameError, %{When objectified_sessions went to create a new instance of the session class, it
couldn't resolve the actual class. You specified #{klass.inspect} as the session class,
but, when we called #constantize on it, we got the following NameError:

(#{ne.class.name}) #{ne}}
          end
        end
      end

      klass
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
  end
end

class ActionController::Base
  def objsession
    @_objsession ||= ::ObjectifiedSessions::_create_new_objsession(session)
  end
end
