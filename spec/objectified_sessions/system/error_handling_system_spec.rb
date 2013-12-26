require 'objectified_sessions'
require "objectified_sessions/helpers/controller_helper"
require "objectified_sessions/helpers/exception_helpers"

describe "ObjectifiedSessions error handling" do
  include ObjectifiedSessions::Helpers::ControllerHelper
  include ObjectifiedSessions::Helpers::ExceptionHelpers

  before :each do
    set_new_controller_instance
    ::ObjectifiedSessions.instance_variable_set("@session_class", nil)
  end

  it "should raise a nice exception if you haven't specified a session class, nor defined one" do
    e = capture_exception(NameError) { @controller_instance.objsession }
    e.message.should match(/Objsession/)
  end

  it "should raise a relevant exception if the specified session class doesn't exist" do
    ::ObjectifiedSessions.session_class = :NonexistentSessionClass1

    e = capture_exception(NameError) { @controller_instance.objsession }
    e.message.should match(/NonexistentSessionClass1/i)
  end

  it "should raise a relevant exception if the specified class can't be instantiated" do
    class FooError < StandardError; end

    define_objsession_class(:CannotInstantiateObjsessionClass) do
      def initialize(*args)
        raise FooError, "kaboomba"
      end
    end

    e = capture_exception(ObjectifiedSessions::Errors::CannotCreateSessionError) { @controller_instance.objsession }
    e.message.should match(/kaboomba/i)
    e.message.should match(/fooerror/i)
    e.message.should match(/CannotInstantiateObjsessionClass/i)
  end

  it "should raise a relevant exception if the specified class isn't a subclass of ObjectifiedSessions::Base" do
    class SomeOtherClass
      def initialize(*args)
      end

      def to_s
        "woomba"
      end
    end

    ::ObjectifiedSessions.session_class = :SomeOtherClass

    e = capture_exception(ObjectifiedSessions::Errors::CannotCreateSessionError) { @controller_instance.objsession }
    e.message.should match(/SomeOtherClass/i)
    e.message.should match(/ObjectifiedSessions::Base/i)
    e.message.should match(/woomba/i)
  end
end
