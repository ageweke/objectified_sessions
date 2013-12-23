require 'objectified_sessions'

module ObjectifiedSessions
  class Base
    def initialize(underlying_session)
      @underlying_session = underlying_session
    end
  end
end
