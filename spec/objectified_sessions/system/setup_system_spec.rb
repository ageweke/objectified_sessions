require 'objectified_sessions'
require "objectified_sessions/helpers/controller_helper"
require "objectified_sessions/helpers/exception_helpers"

describe "ObjectifiedSessions setup" do
  include ObjectifiedSessions::Helpers::ControllerHelper
  include ObjectifiedSessions::Helpers::ExceptionHelpers

  before :each do
    set_new_controller_instance
    ::ObjectifiedSessions.instance_variable_set("@session_class", nil)
  end

  it "should allow setting the session class as a String" do
    class SetupStringSpecifiedClass < ::ObjectifiedSessions::Base; end
    ::ObjectifiedSessions.session_class = 'setup_string_specified_class'
    @controller_instance.objsession.class.should == SetupStringSpecifiedClass
  end

  it "should allow setting the session class as a Symbol" do
    class SetupSymbolSpecifiedClass < ::ObjectifiedSessions::Base; end
    ::ObjectifiedSessions.session_class = :setup_symbol_specified_class
    @controller_instance.objsession.class.should == SetupSymbolSpecifiedClass
  end

  it "should allow setting the session class as a Class" do
    class SetupClassSpecifiedClass < ::ObjectifiedSessions::Base; end
    ::ObjectifiedSessions.session_class = SetupClassSpecifiedClass
    @controller_instance.objsession.class.should == SetupClassSpecifiedClass
  end

  it "should be able to load the session class from a file on the load path" do
    require 'tmpdir'
    require 'fileutils'

    dir = Dir.mktmpdir('objectified_sessions')
    dir = File.expand_path(dir)

    subdir = File.join(dir, 'foo')
    FileUtils.mkdir_p(subdir)

    target_file = File.join(subdir, 'bar.rb')
    File.open(target_file, 'w') do |f|
      f.puts <<-EOF
module Foo
  class Bar < ObjectifiedSessions::Base
    field :foo
  end
end
EOF
    end

    $: << dir
    ::ObjectifiedSessions.session_class = "Foo::Bar"
    @controller_instance.objsession.class.name.should == "Foo::Bar"

    expect(@underlying_session).to receive(:[]=).once.with('foo', 123)
    @controller_instance.objsession.foo = 123

    expect(@underlying_session).to receive(:[]).once.with('foo').and_return(234)
    @controller_instance.objsession.foo.should == 234
  end
end
