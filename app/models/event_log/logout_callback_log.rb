# frozen_string_literal: true

module EventLog
  class LogoutCallbackLog < EventLog::EventLog
    has_one :logout_init_log, class_name: 'LogoutInitLog', primary_key: 'id', foreign_key: 'reference_id'
  end
end
