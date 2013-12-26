require 'objectified_sessions'
require "objectified_sessions/helpers/controller_helper"
require "objectified_sessions/helpers/exception_helpers"

describe "ObjectifiedSessions visibility" do
  include ObjectifiedSessions::Helpers::ControllerHelper
  include ObjectifiedSessions::Helpers::ExceptionHelpers

  before :each do
    set_new_controller_instance
  end

  it "should allow making a field private, and generate only private methods for it" do
    define_objsession_class do
      field :foo, :visibility => :private

      def set_foo(x)
        self.foo = x
      end

      def get_foo
        foo
      end
    end

    @controller_instance.objsession.respond_to?(:foo).should_not be
    @controller_instance.objsession.respond_to?(:foo=).should_not be
    lambda { @controller_instance.objsession.foo }.should raise_error(NoMethodError)
    lambda { @controller_instance.objsession.foo = 123 }.should raise_error(NoMethodError)

    expect(@underlying_session).to receive(:[]=).once.with(:foo, 123)
    @controller_instance.objsession.set_foo(123)

    expect(@underlying_session).to receive(:[]).once.with(:foo).and_return(234)
    @controller_instance.objsession.get_foo.should == 234
  end

  it "should allow setting the default visibility to private, but overriding it on a field-by-field basis" do
    define_objsession_class do
      default_visibility :private

      field :foo
      field :bar, :visibility => :public
    end

    @controller_instance.objsession.respond_to?(:foo).should_not be
    @controller_instance.objsession.respond_to?(:foo=).should_not be
    lambda { @controller_instance.objsession.foo }.should raise_error(NoMethodError)
    lambda { @controller_instance.objsession.foo = 123 }.should raise_error(NoMethodError)

    expect(@underlying_session).to receive(:[]=).once.with(:bar, 123)
    @controller_instance.objsession.bar = 123
    expect(@underlying_session).to receive(:[]).once.with(:bar).and_return(234)
    @controller_instance.objsession.bar.should == 234

    expect(@underlying_session).to receive(:[]=).once.with(:foo, 123)
    @controller_instance.objsession.send(:foo=, 123)
    expect(@underlying_session).to receive(:[]).once.with(:foo).and_return(234)
    @controller_instance.objsession.send(:foo).should == 234
  end
end
