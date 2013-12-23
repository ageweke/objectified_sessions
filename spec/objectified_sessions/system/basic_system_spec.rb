require 'objectified_sessions'
require "objectified_sessions/helpers/controller_helper"

describe "ObjectifiedSessions basic operations", :type => :controller do
  include ObjectifiedSessions::Helpers::ControllerHelper

  before :each do
    set_new_controller_instance
  end

  it "should have an object at #objsession" do
    @controller_instance.objsession.should be
  end
end
