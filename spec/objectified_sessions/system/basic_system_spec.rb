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

    expect(@underlying_session).to receive(:[]=).once.with('foo', 123)
    @controller_instance.objsession.foo = 123

    expect(@underlying_session).to receive(:[]).once.with('foo').and_return(234)
    @controller_instance.objsession.foo.should == 234
  end

  it "should allow specifying a defined field as a String" do
    define_objsession_class { field 'FoO' }

    expect(@underlying_session).to receive(:[]=).once.with('FoO', 123)
    @controller_instance.objsession.foo = 123

    expect(@underlying_session).to receive(:[]).once.with('FoO').and_return(234)
    @controller_instance.objsession.foo.should == 234
  end

  it "should let you redefine a field if it's exactly identical" do
    define_objsession_class { field :foo, :visibility => :private, :storage => :baz }

    @objsession_class.class_eval { field :foo, :visibility => :private, :storage => :baz }

    lambda { @objsession_class.class_eval { field :foo, :visibility => :public, :storage => :baz } }.should raise_error(ObjectifiedSessions::Errors::DuplicateFieldNameError)
    lambda { @objsession_class.class_eval { field :foo, :visibility => :private, :storage => :aaa } }.should raise_error(ObjectifiedSessions::Errors::DuplicateFieldNameError)
    lambda { @objsession_class.class_eval { field :quux, :visibility => :public, :storage => :baz } }.should raise_error(ObjectifiedSessions::Errors::DuplicateFieldStorageNameError)
    lambda { @objsession_class.class_eval { inactive :foo, :visibility => :private, :storage => :baz } }.should raise_error(ObjectifiedSessions::Errors::DuplicateFieldNameError)
    lambda { @objsession_class.class_eval { retired :foo, :visibility => :private, :storage => :baz } }.should raise_error(ObjectifiedSessions::Errors::DuplicateFieldNameError)
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

    expect(@underlying_session).to receive(:[]=).once.with('foo', 123)
    @controller_instance.objsession.set_foo(123)

    expect(@underlying_session).to receive(:[]).once.with('foo').and_return(234)
    @controller_instance.objsession.get_foo.should == 234
  end

  it "should tell you what fields are defined, and which have data" do
    define_objsession_class do
      field :foo
      field :bar
    end

    @controller_instance.objsession.field_names.sort_by(&:to_s).should == [ :foo, :bar ].sort_by(&:to_s)

    expect(@underlying_session).to receive(:[]).once.with('foo').and_return(123)
    expect(@underlying_session).to receive(:[]).once.with('bar').and_return(nil)
    @controller_instance.objsession.keys.should == [ :foo ]

    expect(@underlying_session).to receive(:[]).once.with('foo').and_return(nil)
    expect(@underlying_session).to receive(:[]).once.with('bar').and_return(false)
    @controller_instance.objsession.keys.should == [ :bar ]
  end

  it "should turn itself into a string reasonably well" do
    define_objsession_class do
      field :foo
      field :bar
    end

    ::Object.const_set(:ObjectifiedSessionsSpecBasicString, @objsession_class)

    allow(@underlying_session).to receive(:[]).with('foo').and_return(123)
    allow(@underlying_session).to receive(:[]).with('bar').and_return(nil)
    @controller_instance.objsession.to_s.should == "<ObjectifiedSessionsSpecBasicString: foo: 123>"
    @controller_instance.objsession.inspect.should == @controller_instance.objsession.to_s

    allow(@underlying_session).to receive(:[]).with('foo').and_return(123)
    allow(@underlying_session).to receive(:[]).with('bar').and_return("a" * 200)
    @controller_instance.objsession.to_s.should == "<ObjectifiedSessionsSpecBasicString: bar: \"#{"a" * 36}..., foo: 123>"
    @controller_instance.objsession.inspect.should == @controller_instance.objsession.to_s

    @controller_instance.objsession.to_s(false).should == "<ObjectifiedSessionsSpecBasicString: bar: \"#{"a" * 200}\", foo: 123>"
    @controller_instance.objsession.inspect(false).should == @controller_instance.objsession.to_s(false)
  end

  it "should allow setting a storage name for a field, and should use that when talking to the underlying session" do
    define_objsession_class do
      unknown_fields :delete

      field :foo, :storage => :f
      field :bar, :storage => :b
    end

    allow(@underlying_session).to receive(:keys).and_return([ :foo, :b ])
    expect(@underlying_session).to receive(:delete).once.with([ :foo ])


    expect(@underlying_session).to receive(:[]=).once.with('f', 123)
    @controller_instance.objsession.foo = 123

    expect(@underlying_session).to receive(:[]).once.with('f').and_return(234)
    @controller_instance.objsession.foo.should == 234

    allow(@underlying_session).to receive(:[]).once.with('b').and_return(456)
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
end
