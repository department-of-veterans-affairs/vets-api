# frozen_string_literal: true

module EventLog
  class LogoutInitLog < EventLog::EventLog
    belongs_to :logout_callback_log, class_name: 'EventLog::LogoutCallbackLog', foreign_key: :event_log_id,
                                     inverse_of: :logout_init_log
    has_one :login_callback_log, class_name: 'EventLog:LoginCallbackLog', foreign_key: :event_log_id,
                                 dependent: :nullify, inverse_of: :logout_init_log
  end
end
