require 'objectified_sessions'
require "objectified_sessions/helpers/controller_helper"
require "objectified_sessions/helpers/exception_helpers"

describe "ObjectifiedSessions basic operations" do
  include ObjectifiedSessions::Helpers::ControllerHelper
  include ObjectifiedSessions::Helpers::ExceptionHelpers

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

  it "should allow hash access to the underlying session" do
    define_objsession_class do
      field :foo, :visibility => :private

      def set_foo(x)
        self[:foo] = x
      end

      def get_foo
        self[:foo]
      end
    end

    expect(@underlying_session).to receive(:[]=).once.with(:foo, 123)
    @controller_instance.objsession.set_foo(123)

    expect(@underlying_session).to receive(:[]).once.with(:foo).and_return(234)
    @controller_instance.objsession.get_foo.should == 234
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

  it "should treat symbols and strings in received data identically" do
    define_objsession_class do
      prefix :prf
      unknown_fields :delete

      field :foo
      field :bar
    end

    should_be_using_prefix(:prf, false)
    allow(@underlying_session).to receive(:keys).and_return([ 'foo', 'prf', :baz, :quux ])
    allow(@prefixed_underlying_session).to receive(:keys).and_return([ 'foo', 'aaa', :bbb, :bar ])

    expect(@prefixed_underlying_session).to receive(:delete).once do |arr|
      unless arr.sort_by(&:to_s) == [ 'aaa', :bbb ].sort_by(&:to_s)
        raise "Received :delete with incorrect arguments: #{arr.inspect}"
      end
    end

    allow(@prefixed_underlying_session).to receive(:[]).with(:foo).and_return(123)
    allow(@prefixed_underlying_session).to receive(:[]).with(:bar).and_return(345)

    @controller_instance.objsession.foo.should == 123
    @controller_instance.objsession.bar.should == 345
  end

  it "should allow setting a storage name for a field, and should use that when talking to the underlying session" do
    define_objsession_class do
      unknown_fields :delete

      field :foo, :storage => :f
      field :bar, :storage => :b
    end

    allow(@underlying_session).to receive(:keys).and_return([ :foo, :b ])
    expect(@underlying_session).to receive(:delete).once.with([ :foo ])


    expect(@underlying_session).to receive(:[]=).once.with(:f, 123)
    @controller_instance.objsession.foo = 123

    expect(@underlying_session).to receive(:[]).once.with(:f).and_return(234)
    @controller_instance.objsession.foo.should == 234

    allow(@underlying_session).to receive(:[]).once.with(:b).and_return(456)
    @controller_instance.objsession.bar.should == 456

    lambda { @controller_instance.objsession.send(:f) }.should raise_error(NoMethodError)
    lambda { @controller_instance.objsession.send(:f=) }.should raise_error(NoMethodError)
    lambda { @controller_instance.objsession.send(:b) }.should raise_error(NoMethodError)
    lambda { @controller_instance.objsession.send(:b=) }.should raise_error(NoMethodError)

    lambda { @controller_instance.objsession.send(:[], :f) }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    lambda { @controller_instance.objsession.send(:[]=, :f, 123) }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    lambda { @controller_instance.objsession.send(:[], :b) }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    lambda { @controller_instance.objsession.send(:[]=, :b, 123) }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
  end

  it "should call the included module something sane" do
    define_objsession_class(:IncludedModuleSpecObjSession) { field :foo }

    included = @controller_instance.objsession.class.included_modules.detect { |m| m.name =~ /objectifiedsessions/i }
    included.should be
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
    e.storage_name.should == :bar
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
    e.storage_name.should == :bar
    e.message.should match(/foo/i)
    e.message.should match(/bar/i)
  end
end
