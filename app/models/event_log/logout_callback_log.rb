# frozen_string_literal: true

module EventLog
  class LogoutCallbackLog < EventLog::EventLog
    has_one :logout_init_log, class_name: 'LogoutInitLog', foreign_key: :event_log_id, dependent: :nullify,
                              inverse_of: :logout_callback_log
  end
end
