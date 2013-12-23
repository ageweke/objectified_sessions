require "action_controller"
require "objectified_sessions/version"
require "objectified_sessions/base"

module ObjectifiedSessions
  class << self
    def create_new_objsession(underlying_session)
      ObjectifiedSessions::Base.new(underlying_session)
    end
  end
end

class ActionController::Base
  def objsession
    @_objsession ||= ::ObjectifiedSessions::create_new_objsession(session)
  end
end
