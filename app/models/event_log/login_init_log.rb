# frozen_string_literal: true

module EventLog
  class LoginInitLog < EventLog::EventLog
    belongs_to :login_callback_log, foreign_key: 'reference_id'
  end
end
