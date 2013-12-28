require 'objectified_sessions'
require 'fileutils'

describe ObjectifiedSessionGenerator do
  before :each do
    @dir = Dir.mktmpdir("objectified_sessions_spec_generator")

    allow(::Rails).to receive(:root).with().and_return(@dir)
    FileUtils.mkdir_p(File.join(@dir, "lib"))

    @generator = ObjectifiedSessionGenerator.new

    @puts_msgs = [ ]
    pm = @puts_msgs
    allow($stdout).to receive(:puts) { |*args| pm << args }
  end

  def output
    @puts_msgs.flatten.join("\n")
  end

  after :each do
    FileUtils.rm_rf(@dir) if @dir && File.exist?(@dir)
  end

  context "actual class creation" do
    def expect_class_creation(class_name, subpath)
      @generator.create_session_file

      output.should match(/#{class_name}/)
      output.should match(/#{@dir}/)

      target_file = File.join(@dir, subpath)
      File.exist?(target_file).should be

      const_target = ::Object
      while const_target && class_name =~ /^(.*?)::(.*)$/i
        if const_target.const_defined?($1)
          const_target = const_target.const_get($1)
        else
          const_target = nil
        end
      end

      const_target.send(:remove_const, class_name.to_sym) if const_target && const_target.const_defined?(class_name.to_sym)

      load(target_file)

      klass = class_name.constantize
      klass.superclass.should == ::ObjectifiedSessions::Base
      klass.accessible_field_names.should == [ ]
      klass.default_visibility.should == :public
      klass.prefix.should == nil
      klass.unknown_fields.should == :preserve
    end

    it "should create a normal 'objsession' class" do
      ::ObjectifiedSessions.session_class = ::ObjectifiedSessions::DEFAULT_OBJSESSION_CLASS_NAME
      expect_class_creation("Objsession", "lib/objsession.rb")
    end

    it "should create an alternate class if so configured" do
      ::ObjectifiedSessions.session_class = "FooBar"
      expect_class_creation("FooBar", "lib/foo_bar.rb")
    end

    it "should create a nested class if asked to" do
      ::ObjectifiedSessions.session_class = "BazTest::BarTest::FooBarTest"
      expect_class_creation("BazTest::BarTest::FooBarTest", "lib/baz_test/bar_test/foo_bar_test.rb")
    end
  end

  context "class creation failures" do
    it "should not create an Objsession class if one exists already in the namespace" do
      class Objsession; end
      ::ObjectifiedSessions.session_class = ::ObjectifiedSessions::DEFAULT_OBJSESSION_CLASS_NAME

      @generator.create_session_file
      target_file = File.join(@dir, "lib/objsession.rb")

      File.exist?(target_file).should_not be
      output.should match(/doing nothing/i)
      output.should match(/Objsession/i)
    end

    it "should not create a custom-named class if one exists already in the namespace" do
      class FooBar1; end
      ::ObjectifiedSessions.session_class = :FooBar1

      @generator.create_session_file
      target_file = File.join(@dir, "lib/foo_bar1.rb")

      File.exist?(target_file).should_not be
      output.should match(/doing nothing/i)
      output.should match(/FooBar1/i)
    end

    it "should not create an Objsession class if a file exists on disk" do
      ::ObjectifiedSessions.session_class = ::ObjectifiedSessions::DEFAULT_OBJSESSION_CLASS_NAME
      ::Object.send(:remove_const, :Objsession) if ::Object.const_defined?(:Objsession)

      FileUtils.mkdir_p(File.join(@dir, "lib"))
      File.open(File.join(@dir, "lib/objsession.rb"), "w") { |f| f.puts "hi!" }
      @generator.create_session_file

      output.should match(/already a file/i)
      output.should match(%r{#{@dir}/lib/objsession\.rb}i)
    end

    it "should not create a custom class if a file exists on disk" do
      ::ObjectifiedSessions.session_class = "Foo::Bar2"

      FileUtils.mkdir_p(File.join(@dir, "lib/foo"))
      File.open(File.join(@dir, "lib/foo/bar2.rb"), "w") { |f| f.puts "hi!" }
      @generator.create_session_file

      output.should match(/already a file/i)
      output.should match(%r{#{@dir}/lib/foo/bar2\.rb}i)
    end
  end
end
