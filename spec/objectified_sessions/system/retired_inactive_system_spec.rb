require 'objectified_sessions'
require "objectified_sessions/helpers/controller_helper"
require "objectified_sessions/helpers/exception_helpers"

describe "ObjectifiedSessions retired and inactive field handling" do
  include ObjectifiedSessions::Helpers::ControllerHelper
  include ObjectifiedSessions::Helpers::ExceptionHelpers

  before :each do
    set_new_controller_instance
  end


  describe "retired fields" do
    it "should prevent you from defining a field with the same storage name" do
      e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldNameError) do
        define_objsession_class do
          field :foo

          retired :foo
        end
      end

      e.session_class.should be(@objsession_class)
      e.field_name.should == :foo
      e.message.should match(/foo/i)

      e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldNameError) do
        define_objsession_class do
          retired :foo
          field :foo
        end
      end

      e.session_class.should be(@objsession_class)
      e.field_name.should == :foo
      e.message.should match(/foo/i)

      e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldStorageNameError) do
        define_objsession_class do
          retired :foo
          field :bar, :storage => :foo
        end
      end

      e.session_class.should be(@objsession_class)
      e.original_field_name.should == :foo
      e.new_field_name.should == :bar
      e.storage_name.should == 'foo'
      e.message.should match(/foo/i)
      e.message.should match(/bar/i)
    end

    it "should not allow access to a retired field's data" do
      define_objsession_class do
        field :foo
        retired :bar
      end

      allow(@underlying_session).to receive(:[]).with('foo').and_return(234)

      @controller_instance.objsession.foo.should == 234

      @controller_instance.objsession.respond_to?(:bar).should_not be
      @controller_instance.objsession.respond_to?(:bar=).should_not be

      lambda { @controller_instance.objsession.send(:bar) }.should raise_error(NoMethodError)
      lambda { @controller_instance.objsession.send(:bar=, 123) }.should raise_error(NoMethodError)

      e = capture_exception(ObjectifiedSessions::Errors::NoSuchFieldError) { @controller_instance.objsession.send(:[], :bar) }
      e.accessible_field_names.should == [ :foo ]
      lambda { @controller_instance.objsession.send(:[]=, :bar, 123) }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    end

    it "should still delete such a field's data if the field is retired" do
      define_objsession_class do
        unknown_fields :delete

        field :foo
        retired :bar
      end

      allow(@underlying_session).to receive(:keys).with().and_return([ :foo, :bar ])
      expect(@underlying_session).to receive(:delete).once.with([ :bar ])

      allow(@underlying_session).to receive(:[]).with('foo').and_return(234)

      @controller_instance.objsession.foo.should == 234
    end
  end

  describe "inactive fields" do
    it "should prevent you from defining a field with the same storage name" do
      e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldNameError) do
        define_objsession_class do
          field :foo

          inactive :foo
        end
      end

      e.session_class.should be(@objsession_class)
      e.field_name.should == :foo
      e.message.should match(/foo/i)

      e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldNameError) do
        define_objsession_class do
          inactive :foo
          field :foo
        end
      end

      e.session_class.should be(@objsession_class)
      e.field_name.should == :foo
      e.message.should match(/foo/i)

      e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldStorageNameError) do
        define_objsession_class do
          inactive :foo
          field :bar, :storage => :foo
        end
      end

      e.session_class.should be(@objsession_class)
      e.original_field_name.should == :foo
      e.new_field_name.should == :bar
      e.storage_name.should == 'foo'
      e.message.should match(/foo/i)
      e.message.should match(/bar/i)
    end

    it "should not allow access to an inactive field's data" do
      define_objsession_class do
        field :foo
        inactive :bar
      end

      allow(@underlying_session).to receive(:[]).with('foo').and_return(234)

      @controller_instance.objsession.foo.should == 234

      @controller_instance.objsession.respond_to?(:bar).should_not be
      @controller_instance.objsession.respond_to?(:bar=).should_not be

      lambda { @controller_instance.objsession.send(:bar) }.should raise_error(NoMethodError)
      lambda { @controller_instance.objsession.send(:bar=, 123) }.should raise_error(NoMethodError)

      e = capture_exception(ObjectifiedSessions::Errors::NoSuchFieldError) { @controller_instance.objsession.send(:[], :bar) }
      e.accessible_field_names.should == [ :foo ]
      lambda { @controller_instance.objsession.send(:[]=, :bar, 123) }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    end

    it "should NOT delete such a field's data if the field is inactive" do
      define_objsession_class do
        unknown_fields :delete

        field :foo
        inactive :bar
      end

      allow(@underlying_session).to receive(:keys).with().and_return([ :foo, :bar ])

      allow(@underlying_session).to receive(:[]).with('foo').and_return(234)

      @controller_instance.objsession.foo.should == 234
    end
  end

  it "should let you override a method, and #super should still work" do
    define_objsession_class do
      field :foo

      def foo
        "X" + super + "Y"
      end

      def foo=(x)
        super("A" + x + "B")
      end
    end

    expect(@underlying_session).to receive(:[]=).once.with('foo', "AzB")
    @controller_instance.objsession.foo = 'z'

    expect(@underlying_session).to receive(:[]).once.with('foo').and_return("q")
    @controller_instance.objsession.foo.should == 'XqY'
  end
end
