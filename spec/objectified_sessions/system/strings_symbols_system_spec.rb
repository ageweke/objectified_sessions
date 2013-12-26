require 'objectified_sessions'
require "objectified_sessions/helpers/controller_helper"
require "objectified_sessions/helpers/exception_helpers"

describe "ObjectifiedSessions strings vs. symbols" do
  include ObjectifiedSessions::Helpers::ControllerHelper
  include ObjectifiedSessions::Helpers::ExceptionHelpers

  before :each do
    set_new_controller_instance
  end

  it "should always set and get by String, never Symbol" do
    define_objsession_class { field :foo }

    expect(@underlying_session).to receive(:[]=).once.with('foo', 123)
    @controller_instance.objsession.foo = 123

    expect(@underlying_session).to receive(:[]=).once.with('foo', 123)
    @controller_instance.objsession.send(:[]=, :foo, 123)

    expect(@underlying_session).to receive(:[]).once.with('foo').and_return(234)
    @controller_instance.objsession.foo.should == 234

    expect(@underlying_session).to receive(:[]).once.with('foo').and_return(234)
    @controller_instance.objsession.send(:[], :foo).should == 234
  end

  it "should treat symbols and strings in received data identically" do
    define_objsession_class do
      prefix :prf
      unknown_fields :delete

      field :foo
      field :bar
    end

    should_be_using_prefix('prf', false)
    allow(@underlying_session).to receive(:keys).and_return([ 'foo', 'prf', :baz, :quux ])
    allow(@prefixed_underlying_session).to receive(:keys).and_return([ 'foo', 'aaa', :bbb, :bar ])

    expect(@prefixed_underlying_session).to receive(:delete).once do |arr|
      unless arr.sort_by(&:to_s) == [ 'aaa', :bbb ].sort_by(&:to_s)
        raise "Received :delete with incorrect arguments: #{arr.inspect}"
      end
    end

    allow(@prefixed_underlying_session).to receive(:[]).with('foo').and_return(123)
    allow(@prefixed_underlying_session).to receive(:[]).with('bar').and_return(345)

    @controller_instance.objsession.foo.should == 123
    @controller_instance.objsession.bar.should == 345
  end

  it "should preserve and delete data correctly, whether it's specified as a String or a Symbol" do
    define_objsession_class do
      unknown_fields :delete

      field :preserve1
      field :preserve2
    end

    expect(@underlying_session).to receive(:keys).once.with().and_return([ :preserve1, 'preserve2', :delete1, 'delete2' ])
    expect(@underlying_session).to receive(:delete).once do |arr|
      unless arr.sort_by(&:to_s) == [ :delete1, 'delete2' ].sort_by(&:to_s)
        raise "Received :delete with incorrect arguments: #{arr.inspect}"
      end
    end

    allow(@underlying_session).to receive(:[]).with('preserve1').and_return(234)
    @controller_instance.objsession.preserve1.should == 234
  end
end
