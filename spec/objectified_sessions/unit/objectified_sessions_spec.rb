require 'objectified_sessions'
require 'objectified_sessions/helpers/exception_helpers'

describe ObjectifiedSessions do
  include ObjectifiedSessions::Helpers::ExceptionHelpers

  describe "session_class" do
    before :each do
      ObjectifiedSessions.instance_variable_set("@session_class", nil)
    end

    it "should return the default name, by default" do
      ObjectifiedSessions.session_class.should == "Objsession"
    end

    it "should accept a String and return that" do
      ObjectifiedSessions.session_class = "Foo"
      ObjectifiedSessions.session_class.should == "Foo"
    end

    it "should accept a Symbol and return a String" do
      ObjectifiedSessions.session_class = :Foo
      ObjectifiedSessions.session_class.should == 'Foo'
    end

    it "should camelize its input" do
      ObjectifiedSessions.session_class = "foo/bar_baz"
      ObjectifiedSessions.session_class.should == "Foo::BarBaz"

      ObjectifiedSessions.session_class = :"foo/bar_baz"
      ObjectifiedSessions.session_class.should == "Foo::BarBaz"
    end

    it "should accept a Class and return that" do
      class FooBar; end

      ObjectifiedSessions.session_class = FooBar
      ObjectifiedSessions.session_class.should == FooBar
    end
  end

  describe "_create_new_objsession" do
    before :each do
      @underlying_session = double("underlying_session")

      @session_class_instance = double("session_class_instance")

      @session_class = Class.new(::ObjectifiedSessions::Base)
      allow(@session_class).to receive(:new).once.with(@underlying_session).and_return(@session_class_instance)
      allow(@session_class).to receive(:name).with().and_return("scname")

      allow(@session_class_instance).to receive(:kind_of?).with(::ObjectifiedSessions::Base).and_return(true)

      ObjectifiedSessions.session_class = @session_class
    end

    it "should happily return a new instance of a valid class, and return new ones each time" do
      ObjectifiedSessions._create_new_objsession(@underlying_session).should be(@session_class_instance)

      new_instance = double("session_class_instance_2")
      allow(new_instance).to receive(:kind_of?).with(::ObjectifiedSessions::Base).and_return(true)

      expect(@session_class).to receive(:new).once.with(@underlying_session).and_return(new_instance)
      ObjectifiedSessions._create_new_objsession(@underlying_session).should be(new_instance)
    end

    it "should pass through the underlying session correctly" do
      ObjectifiedSessions._create_new_objsession(@underlying_session).should be(@session_class_instance)

      session_class_instance_2 = double("session_class_instance_2")
      allow(session_class_instance_2).to receive(:kind_of?).with(::ObjectifiedSessions::Base).and_return(true)

      underlying_session_2 = double("underlying_session_2")
      allow(@session_class).to receive(:new).once.with(underlying_session_2).and_return(session_class_instance_2)

      ObjectifiedSessions._create_new_objsession(underlying_session_2).should be(session_class_instance_2)
    end

    it "should fail with a nice exception if #new fails" do
      class FooError < StandardError; end

      allow(@session_class).to receive(:new).once.with(@underlying_session) do |*args|
        raise FooError, "kaboomba"
      end

      e = capture_exception(ObjectifiedSessions::Errors::CannotCreateSessionError) { ObjectifiedSessions._create_new_objsession(@underlying_session) }
      e.message.should match(/fooerror/i)
      e.message.should match(/kaboomba/i)
      e.message.should match(/scname/i)
    end

    it "should fail with a nice exception if the returned instance isn't of the right type" do
      allow(@session_class_instance).to receive(:kind_of?).with(::ObjectifiedSessions::Base).and_return(false)
      allow(@session_class_instance).to receive(:class).with().and_return(@session_class)
      allow(@session_class_instance).to receive(:inspect).with().and_return("sciinspect")

      e = capture_exception(ObjectifiedSessions::Errors::CannotCreateSessionError) { ObjectifiedSessions._create_new_objsession(@underlying_session) }
      e.message.should match(/scname/i)
      e.message.should match(/sciinspect/i)
    end

    context "with constantization needed" do
      before :each do
        @class_name_string = "foo/bar_baz"
        allow(@class_name_string).to receive(:to_s).with().and_return(@class_name_string)

        @underscored_class_name_string = "bonko"

        @camelized_class_name_string = "Foo::BarBaz"
        allow(@class_name_string).to receive(:camelize).with().and_return(@camelized_class_name_string)
        allow(@camelized_class_name_string).to receive(:constantize).once.with().and_return(@session_class)
        allow(@camelized_class_name_string).to receive(:underscore).with().and_return(@underscored_class_name_string)

        ObjectifiedSessions.session_class = @class_name_string
      end

      it "should require paths to classes, convert between underscored and camelized, and call #constantize properly" do
        expect(::ObjectifiedSessions).to receive(:require).once.with(@underscored_class_name_string)
        ObjectifiedSessions._create_new_objsession(@underlying_session).should be(@session_class_instance)
      end

      it "should raise an error if the class can't be #constantize'd" do
        expect(::ObjectifiedSessions).to receive(:require).once.with(@underscored_class_name_string)
        allow(@camelized_class_name_string).to receive(:constantize).once.with() do |*args|
          raise NameError, "noway"
        end

        e = capture_exception(NameError) { ObjectifiedSessions._create_new_objsession(@underlying_session) }
        e.message.should match(/noway/)
        e.message.should match(/#{@camelized_class_name_string}/)
      end

      it "should include a LoadError, if there is one" do
        expect(::ObjectifiedSessions).to receive(:require).once.with(@underscored_class_name_string) do |*args|
          raise LoadError, "blahblahload"
        end

        allow(@camelized_class_name_string).to receive(:constantize).once.with() do |*args|
          raise NameError, "noway"
        end

        e = capture_exception(NameError) { ObjectifiedSessions._create_new_objsession(@underlying_session) }
        e.message.should match(/noway/)
        e.message.should match(/#{@camelized_class_name_string}/)
        e.message.should match(/blahblahload/)
      end
    end
  end
end
