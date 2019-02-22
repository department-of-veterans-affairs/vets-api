# frozen_string_literal: true

module EventLog
  class LoginCallbackLog < EventLog::EventLog
    has_one :login_init_log, class_name: 'LoginInitLog', primary_key: 'id', foreign_key: 'reference_id'
  end
end
