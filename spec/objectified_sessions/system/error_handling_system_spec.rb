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

  describe "session-class specification" do
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

  describe "visibility and prefix specification" do
    it "should raise a nice error if you try to set the default visibility to something bogus" do
      e = capture_exception(ArgumentError) do
        define_objsession_class do
          default_visibility true
        end
      end

      e.message.should match(/true/)
      e.message.should match(/public/)
      e.message.should match(/private/)
    end

    it "should raise a nice error if you try to set the prefix to something bogus" do
      e = capture_exception(ArgumentError) do
        define_objsession_class do
          prefix true
        end
      end

      e.message.should match(/true/)
    end

    it "should raise a nice error if you try to set the unknown-fields setting to something bogus" do
      e = capture_exception(ArgumentError) do
        define_objsession_class do
          unknown_fields true
        end
      end

      e.message.should match(/delete/)
      e.message.should match(/preserve/)
    end
  end

  describe "field specification" do
    it "should raise a nice error if you don't pass a String or Symbol as your field name" do
      e = capture_exception(ArgumentError) do
        define_objsession_class do
          field 123
        end
      end

      e.message.should match(/123/)
    end

    it "should raise a nice error if you pass an invalid option" do
      e = capture_exception(ArgumentError) do
        define_objsession_class do
          field :foo, :a => :b
        end
      end

      e.message.should match(/a/)
    end

    it "should raise a nice error if you pass an invalid :storage option" do
      e = capture_exception(ArgumentError) do
        define_objsession_class do
          field :foo, :storage => false
        end
      end

      e.message.should match(/false/)
    end

    it "should raise a nice error if you pass an invalid :visibility option" do
      e = capture_exception(ArgumentError) do
        define_objsession_class do
          field :foo, :visibility => 12345
        end
      end

      e.message.should match(/12345/)
    end
  end

  it "should not allow hash access to the underlying session for undefined fields" do
    define_objsession_class do
      field :foo, :visibility => :private
      field :baz

      def set_bar(x)
        self[:bar] = x
      end

      def get_bar
        self[:bar]
      end
    end

    e = capture_exception(ObjectifiedSessions::Errors::NoSuchFieldError) { @controller_instance.objsession.set_bar(123) }
    e.session_class.should be(@objsession_class)
    e.field_name.should == :bar
    e.accessible_field_names.sort_by(&:to_s).should == [ :foo, :baz ].sort_by(&:to_s)
    e.message.should match(/bar/i)
    e.message.should match(/foo/i)
    e.message.should match(/baz/i)

    e = capture_exception(ObjectifiedSessions::Errors::NoSuchFieldError) { @controller_instance.objsession.get_bar }
    e.session_class.should be(@objsession_class)
    e.field_name.should == :bar
    e.accessible_field_names.sort_by(&:to_s).should == [ :foo, :baz ].sort_by(&:to_s)
    e.message.should match(/bar/i)
    e.message.should match(/foo/i)
    e.message.should match(/baz/i)
  end

  it "should not let you define more than one field with the same name" do
    e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldNameError) do
      define_objsession_class do
        field :foo
        field 'foo'
      end
    end

    e.session_class.should be(@objsession_class)
    e.field_name.should == :foo
    e.message.should match(/foo/i)
  end

  it "should not let you define more than one field with the same storage name" do
    e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldStorageNameError) do
      define_objsession_class do
        field :foo, :storage => :bar
        field :baz, :storage => :bar
      end
    end

    e.session_class.should be(@objsession_class)
    e.original_field_name.should == :foo
    e.new_field_name.should == :baz
    e.storage_name.should == 'bar'
    e.message.should match(/foo/i)
    e.message.should match(/baz/i)
    e.message.should match(/bar/i)

    e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldStorageNameError) do
      define_objsession_class do
        field :foo, :storage => :bar
        field :bar
      end
    end

    e.session_class.should be(@objsession_class)
    e.original_field_name.should == :foo
    e.new_field_name.should == :bar
    e.storage_name.should == 'bar'
    e.message.should match(/foo/i)
    e.message.should match(/bar/i)
  end
end
