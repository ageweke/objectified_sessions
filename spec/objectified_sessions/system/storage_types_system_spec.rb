require 'objectified_sessions'
require "objectified_sessions/helpers/controller_helper"
require "objectified_sessions/helpers/exception_helpers"

describe "ObjectifiedSessions storage types" do
  include ObjectifiedSessions::Helpers::ControllerHelper
  include ObjectifiedSessions::Helpers::ExceptionHelpers

  before :each do
    set_new_controller_instance
  end

  it "should have an object at #objsession, even with an empty class" do
    define_objsession_class { }
    @controller_instance.objsession.should be
  end

  it "should, by default, allow storing anything in the session" do
    define_objsession_class { field :foo }

    some_class = Class.new
    some_object = some_class.new
    some_object.instance_variable_set("@bar", 345)
    some_object.instance_variable_set("@baz", /yo/)

    expect(@underlying_session).to receive(:[]=).once.with('foo', some_object)
    @controller_instance.objsession.foo = some_object
  end

  it "should allow storing anything in the session if explicitly told to" do
    define_objsession_class do
      field :foo
      allowed_value_types :anything
    end

    some_class = Class.new
    some_object = some_class.new
    some_object.instance_variable_set("@bar", 345)
    some_object.instance_variable_set("@baz", /yo/)

    expect(@underlying_session).to receive(:[]=).once.with('foo', some_object)
    @controller_instance.objsession.foo = some_object
  end

  describe ":primitive_and_compound" do
    before :each do
      define_objsession_class do
        field :foo
        field :bar

        allowed_value_types :primitive_and_compound
      end
    end

    it "should allow storing scalars" do
      expect(@underlying_session).to receive(:[]=).once.with('foo', "foobar")
      expect { @controller_instance.objsession.foo = "foobar" }.not_to raise_error

      expect(@underlying_session).to receive(:[]=).once.with('bar', 134832.32)
      expect { @controller_instance.objsession.bar = 134832.32 }.not_to raise_error

      expect(@underlying_session).to receive(:[]=).once.with('foo', true)
      expect { @controller_instance.objsession.foo = true }.not_to raise_error

      expect(@underlying_session).to receive(:[]=).once.with('bar', false)
      expect { @controller_instance.objsession.bar = false }.not_to raise_error

      expect(@underlying_session).to receive(:[]=).once.with('foo', nil)
      expect { @controller_instance.objsession.foo = nil }.not_to raise_error

      expect(@underlying_session).to receive(:[]=).once.with('foo', :baz)
      expect { @controller_instance.objsession.foo = :baz }.not_to raise_error

      t = Time.now
      expect(@underlying_session).to receive(:[]=).once.with('foo', t)
      expect { @controller_instance.objsession.foo = t }.not_to raise_error
    end

    it "should allow storing Arrays of scalars" do
      expect(@underlying_session).to receive(:[]=).once.with('foo', [ 3, 'foo', :zap ])
      expect { @controller_instance.objsession.foo = [ 3, 'foo', :zap ] }.not_to raise_error
    end

    it "should allow storing Hashes of scalars" do
      expect(@underlying_session).to receive(:[]=).once.with('foo', { :one => 1, 'two' => 2 })
      expect { @controller_instance.objsession.foo = { :one => 1, 'two' => 2 } }.not_to raise_error
    end

    it "should allow storing compound Arrays" do
      expect(@underlying_session).to receive(:[]=).once.with('foo', [ 3, [ 2, 4 ], { 'foo' => 'bar' } ])
      expect { @controller_instance.objsession.foo = [ 3, [ 2, 4 ], { 'foo' => 'bar' } ] }.not_to raise_error
    end

    it "should allow storing compound Hashes" do
      expect(@underlying_session).to receive(:[]=).once.with('foo', { [ 1, 2 ] => 'onetwo', 3 => { :bar => [ :foo, 'baz' ] } })
      expect { @controller_instance.objsession.foo = { [ 1, 2 ] => 'onetwo', 3 => { :bar => [ :foo, 'baz' ] } } }.not_to raise_error
    end

    it "should not allow storing invalid scalars" do
      expect { @controller_instance.objsession.foo = /yo/ }.to raise_error(ArgumentError)
    end

    it "should not allow storing invalid scalars inside an Array" do
      expect { @controller_instance.objsession.foo = [ 1, 2, /yo/ ] }.to raise_error(ArgumentError)
    end

    it "should not allow storing invalid scalars inside a Hash" do
      expect { @controller_instance.objsession.foo = { :foo => /yo/ } }.to raise_error(ArgumentError)
      expect { @controller_instance.objsession.foo = { /yo/ => :foo } }.to raise_error(ArgumentError)
    end
  end

  describe ":primitive" do
    before :each do
      define_objsession_class do
        field :foo
        field :bar

        allowed_value_types :primitive
      end
    end

    it "should allow storing scalars" do
      expect(@underlying_session).to receive(:[]=).once.with('foo', "foobar")
      expect { @controller_instance.objsession.foo = "foobar" }.not_to raise_error

      expect(@underlying_session).to receive(:[]=).once.with('bar', 134832.32)
      expect { @controller_instance.objsession.bar = 134832.32 }.not_to raise_error

      expect(@underlying_session).to receive(:[]=).once.with('foo', true)
      expect { @controller_instance.objsession.foo = true }.not_to raise_error

      expect(@underlying_session).to receive(:[]=).once.with('bar', false)
      expect { @controller_instance.objsession.bar = false }.not_to raise_error

      expect(@underlying_session).to receive(:[]=).once.with('foo', nil)
      expect { @controller_instance.objsession.foo = nil }.not_to raise_error

      expect(@underlying_session).to receive(:[]=).once.with('foo', :baz)
      expect { @controller_instance.objsession.foo = :baz }.not_to raise_error

      t = Time.now
      expect(@underlying_session).to receive(:[]=).once.with('foo', t)
      expect { @controller_instance.objsession.foo = t }.not_to raise_error
    end

    it "should not allow storing Arrays of scalars" do
      expect { @controller_instance.objsession.foo = [ 3, 'foo', :zap ] }.to raise_error(ArgumentError)
    end

    it "should not allow storing Hashes of scalars" do
      expect { @controller_instance.objsession.foo = { :one => 1, 'two' => 2 } }.to raise_error(ArgumentError)
    end

    it "should not allow storing compound Arrays" do
      expect { @controller_instance.objsession.foo = [ 3, [ 2, 4 ], { 'foo' => 'bar' } ] }.to raise_error(ArgumentError)
    end

    it "should not allow storing compound Hashes" do
      expect { @controller_instance.objsession.foo = { [ 1, 2 ] => 'onetwo', 3 => { :bar => [ :foo, 'baz' ] } } }.to raise_error(ArgumentError)
    end

    it "should not allow storing invalid scalars" do
      expect { @controller_instance.objsession.foo = /yo/ }.to raise_error(ArgumentError)
    end

    it "should not allow storing invalid scalars inside an Array" do
      expect { @controller_instance.objsession.foo = [ 1, 2, /yo/ ] }.to raise_error(ArgumentError)
    end

    it "should not allow storing invalid scalars inside a Hash" do
      expect { @controller_instance.objsession.foo = { :foo => /yo/ } }.to raise_error(ArgumentError)
      expect { @controller_instance.objsession.foo = { /yo/ => :foo } }.to raise_error(ArgumentError)
    end
  end
end
