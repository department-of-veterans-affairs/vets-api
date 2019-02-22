# frozen_string_literal: true

module EventLog
  class LogoutInitLog < EventLog::EventLog
    belongs_to :logout_callback_log, foreign_key: 'reference_id'
  end
end
