require 'objectified_sessions'
require "objectified_sessions/helpers/controller_helper"
require "objectified_sessions/helpers/exception_helpers"

describe "ObjectifiedSessions unknown-data handling" do
  include ObjectifiedSessions::Helpers::ControllerHelper
  include ObjectifiedSessions::Helpers::ExceptionHelpers

  before :each do
    set_new_controller_instance
  end

  it "should not remove unknown data by default" do
    define_objsession_class { field :foo; field :bar }

    allow(@underlying_session).to receive(:keys).with().and_return([ :foo, :baz, :quux ])
    allow(@underlying_session).to receive(:[]).with('foo').and_return(234)

    @controller_instance.objsession.foo.should == 234
  end

  it "should remove unknown data if asked to" do
    define_objsession_class do
      unknown_fields :delete

      field :foo
      field :bar
    end

    allow(@underlying_session).to receive(:keys).with().and_return([ :foo, :baz, :quux ])
    expect(@underlying_session).to receive(:delete).once do |arr|
      unless arr.sort_by(&:to_s) == [ :baz, :quux ].sort_by(&:to_s)
        raise "Received :delete with incorrect arguments: #{arr.inspect}"
      end
    end

    allow(@underlying_session).to receive(:[]).with('foo').and_return(234)

    @controller_instance.objsession.foo.should == 234
  end

  it "should not remove unknown data from outside the prefix" do
    define_objsession_class do
      prefix :prf
      unknown_fields :delete

      field :foo
      field :bar
    end

    should_be_using_prefix('prf', false)
    allow(@underlying_session).to receive(:keys).and_return([ :foo, :prf, :baz, :quux ])
    allow(@prefixed_underlying_session).to receive(:keys).and_return([ :foo, :aaa, :bbb ])

    expect(@prefixed_underlying_session).to receive(:delete).once do |arr|
      unless arr.sort_by(&:to_s) == [ :aaa, :bbb ].sort_by(&:to_s)
        raise "Received :delete with incorrect arguments: #{arr.inspect}"
      end
    end

    allow(@prefixed_underlying_session).to receive(:[]).with('foo').and_return(123)

    @controller_instance.objsession.foo.should == 123
  end
end
