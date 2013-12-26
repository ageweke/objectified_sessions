require 'objectified_sessions'
require "objectified_sessions/helpers/controller_helper"
require "objectified_sessions/helpers/exception_helpers"

describe "ObjectifiedSessions prefix" do
  include ObjectifiedSessions::Helpers::ControllerHelper
  include ObjectifiedSessions::Helpers::ExceptionHelpers

  before :each do
    set_new_controller_instance
  end

  it "should allow setting a prefix, and then the underlying session should always be accessed via that Hash" do
    define_objsession_class do
      prefix :prf

      field :foo
      field :bar
    end

    @objsession_class.prefix.should == 'prf'

    should_be_using_prefix('prf', true)

    expect(@prefixed_underlying_session).to receive(:[]=).once.with('foo', 123)
    @controller_instance.objsession.foo = 123

    expect(@prefixed_underlying_session).to receive(:[]).once.with('foo').and_return(234)
    @controller_instance.objsession.foo.should == 234
  end

  it "should allow setting a prefix, and return nil for everything if nothing's been set there" do
    define_objsession_class do
      prefix :prf

      field :foo
      field :bar
    end

    allow(@underlying_session).to receive(:[]).with('prf').and_return(nil)

    @controller_instance.objsession.foo.should == nil
    @controller_instance.objsession.bar.should == nil
  end

  it "should allow setting the prefix to nil, which shouldn't change anything" do
    define_objsession_class do
      prefix nil

      field :foo
      field :bar
    end

    @objsession_class.prefix.should == nil

    expect(@underlying_session).to receive(:[]=).once.with('foo', 123)
    @controller_instance.objsession.foo = 123

    expect(@underlying_session).to receive(:[]).once.with('foo').and_return(234)
    @controller_instance.objsession.foo.should == 234
  end
end
