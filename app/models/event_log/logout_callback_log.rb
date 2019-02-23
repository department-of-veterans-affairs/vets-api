# frozen_string_literal: true

module EventLog
  class LogoutCallbackLog < Log
    belongs_to :logout_init_log, foreign_key: :event_log_id, inverse_of: :logout_callback_log, dependent: :nullify
  end
end
