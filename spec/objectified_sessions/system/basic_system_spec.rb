require 'objectified_sessions'
require "objectified_sessions/helpers/controller_helper"

describe "ObjectifiedSessions basic operations", :type => :controller do
  include ObjectifiedSessions::Helpers::ControllerHelper

  before :each do
    set_new_controller_instance
  end

  it "should have an object at #objsession, even with an empty class" do
    define_objsession_class { }
    @controller_instance.objsession.should be
  end

  it "should allow setting and getting a defined field, and read/write that on the underlying session" do
    define_objsession_class { field :foo }

    expect(@underlying_session).to receive(:[]=).once.with(:foo, 123)
    @controller_instance.objsession.foo = 123

    expect(@underlying_session).to receive(:[]).once.with(:foo).and_return(234)
    @controller_instance.objsession.foo.should == 234
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

  it "should call the included module something sane"
end
