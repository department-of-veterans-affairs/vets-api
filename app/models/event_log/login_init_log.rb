# frozen_string_literal: true

module EventLog
  class LoginInitLog < EventLog::EventLog
    belongs_to :login_callback_log, class_name: 'EventLog::LoginCallbackLog', foreign_key: :event_log_id,
                                    inverse_of: :login_init_log
  end
end
