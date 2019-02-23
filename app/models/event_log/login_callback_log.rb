# frozen_string_literal: true

module EventLog
  class LoginCallbackLog < EventLog::EventLog
    has_one :login_init_log, class_name: 'LoginInitLog', foreign_key: :event_log_id, dependent: :nullify,
                             inverse_of: :login_callback_log
    belongs_to :logout_init_log, class_name: 'EventLog::LogoutInitLog', foreign_key: :event_log_id,
                                 inverse_of: :login_callback_log
  end
end
