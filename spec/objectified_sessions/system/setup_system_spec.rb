require 'objectified_sessions'
require "objectified_sessions/helpers/controller_helper"
require "objectified_sessions/helpers/exception_helpers"

describe "ObjectifiedSessions setup" do
  include ObjectifiedSessions::Helpers::ControllerHelper
  include ObjectifiedSessions::Helpers::ExceptionHelpers

  before :each do
    set_new_controller_instance
    ::ObjectifiedSessions.instance_variable_set("@session_class", nil)
  end

  it "should allow setting the session class as a String" do
    class SetupStringSpecifiedClass < ::ObjectifiedSessions::Base; end
    ::ObjectifiedSessions.session_class = 'setup_string_specified_class'
    @controller_instance.objsession.class.should == SetupStringSpecifiedClass
  end

  it "should allow setting the session class as a Symbol" do
    class SetupSymbolSpecifiedClass < ::ObjectifiedSessions::Base; end
    ::ObjectifiedSessions.session_class = :setup_symbol_specified_class
    @controller_instance.objsession.class.should == SetupSymbolSpecifiedClass
  end

  it "should allow setting the session class as a Class" do
    class SetupClassSpecifiedClass < ::ObjectifiedSessions::Base; end
    ::ObjectifiedSessions.session_class = SetupClassSpecifiedClass
    @controller_instance.objsession.class.should == SetupClassSpecifiedClass
  end
end
