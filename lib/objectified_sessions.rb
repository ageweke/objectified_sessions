require "action_controller"
require "objectified_sessions/version"
require "objectified_sessions/base"
require "objectified_session_generator"

# ObjectifiedSessions is the outermost interface to the ObjectifiedSessions Gem. This module exists only as a namespace
# (_i.e._, is not included into any classes), and has a single public method, #session_class, that lets you configure
# which class is to be used as your +objsession+.
module ObjectifiedSessions
  DEFAULT_OBJSESSION_CLASS_NAME = "Objsession"

  class << self
    # Should be called from code internal to the ObjectifiedSessions Gem only. Given the underlying Session object
    # (as returned by `#session` in a controller), creates a new instance of the correct objectified-session class
    # and returns it.
    #
    # This method is actually trivially simple; it's more than two lines just because we want to be careful to raise
    # good, usable exceptions if there's a problem.
    def _create_new_objsession(underlying_session)
      klass = _session_class_object
      out = nil

      # Create a new instance...
      begin
        out = klass.new(underlying_session)
      rescue Exception => e
        raise ObjectifiedSessions::Errors::CannotCreateSessionError, %{When objectified_sessions went to create a new instance of the session class, it
got an exception from the call to #{klass.name}.new:

(#{e.class.name}) #{e.message}
    #{e.backtrace.join("\n    ")}}
      end

      # ...and make sure it's a subclass of ::ObjectifiedSessions::Base.
      unless out.kind_of?(::ObjectifiedSessions::Base)
        raise ObjectifiedSessions::Errors::CannotCreateSessionError, %{When objectified_sessions went to create a new instance of the session class, it
got back an object that isn't an instance of a subclass of ObjectifiedSessions::Base.

It got back an instance of #{out.class.name}:
#{out.inspect}}
      end

      out
    end

    # Returns the session class that's been set -- in whatever format it's been set. This means that the return value
    # can be a String, Symbol, or Class, depending on how the client set it.
    def session_class
      @session_class ||= DEFAULT_OBJSESSION_CLASS_NAME
    end

    # Sets the class that should be instantiated and bound to #objsession in controllers. You can pass a String or
    # Symbol that's the name of the class, or the actual Class object itself.
    #
    # Class loading: if the class is not already loaded, then ObjectifiedSessions will attempt to load it, using
    # Kernel#require, using a file path that's the Rails-style mapping from the name of the class. (In other words,
    # if you pass 'Foo::BarBaz' for +target_class+, then ObjectifiedSessions will <tt>require 'foo/bar_baz'</tt>.)
    #
    # However specified, the class must be a subclass of ObjectifiedSessions::Base, or you'll get an error when you
    # call #objsession.
    #
    # Note that this is evaluated the first time you call #objsession from within a controller, not immediately. This
    # means your application will be fully booted and all of Rails available when you do this, but it also means that
    # if you set a class that can't be resolved or has an error in it, you won't find out until you first try to access
    # the #objsession. Be aware.
    def session_class=(target_class)
      unless [ String, Symbol, Class ].include?(target_class.class)
        raise ArgumentError, "You must pass a String, Symbol, or Class, not: #{target_class.inspect}"
      end

      if target_class.kind_of?(String) || target_class.kind_of?(Symbol)
        target_class = target_class.to_s.camelize
      end

      @session_class = target_class
      @_session_class_object = nil
    end

    private
    # Returns the actual Class object specified by #session_class, above. This is the method that does the work of
    # resolving a String or Symbol that was passed there.
    def _session_class_object
      # We cache this so that we don't call #constantize, a relatively expensive operation, every time we need to
      # instantiate a new #objsession.
      @_session_class_object ||= begin
        klass = session_class

        unless klass.kind_of?(Class)
          path = nil
          load_error = nil

          begin
            # Compute the path this class would have...
            path = klass.underscore

            # ...and try to Kernel#require it. If we get an error, that's fine; we'll keep going and try to use the
            # class anyway -- but we'll report on it if that fails, since it's very useful information in debugging.
            begin
              require path
            rescue LoadError => le
              load_error = le
            end

            klass = klass.constantize
          rescue NameError => ne
            message = nil

            # If you haven't changed the default session-class name, then you probably just haven't run the generator;
            # let's tell you to do that.
            if klass.to_s == DEFAULT_OBJSESSION_CLASS_NAME.to_s
              message = %{Before using objectified_sessions, you need to define the class that implements your
  objectfied session. By default, this is named #{klass.inspect}; simply create a class of
  that name, in the appropriate place in your project (e.g., lib/objsession.rb). You can
  run 'rails generate objectified_session' to do this for you.

  Alternatively, tell objectified_sessions to use a particular class, by saying

    ObjectifiedSessions.session_class = <class name>

  somewhere in your config/application.rb, or some similar initialization code.}
            else
              # If you *have* changed the default session-class name, you probably know what you're doing, so let's
              # give you a different error message.
              message = %{When objectified_sessions went to create a new instance of the session class, it
  couldn't resolve the actual class. You specified #{klass.inspect} as the session class,
  but, when we called #constantize on it, we got the following NameError:

  (#{ne.class.name}) #{ne}}
            end

            # This is where we add information about the LoadError, above.
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
end

# This is what actually makes #objsession in a controller work. Returns an instance of whatever class you have specified
# as your objectified-session class (usually just named +Objsession+).
class ActionController::Base
  def objsession
    @_objsession ||= ::ObjectifiedSessions::_create_new_objsession(session)
  end
end
