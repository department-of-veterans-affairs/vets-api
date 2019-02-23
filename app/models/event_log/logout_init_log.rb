# frozen_string_literal: true

module EventLog
  class LogoutInitLog < Log
    has_one :logout_callback_log, foreign_key: :event_log_id, inverse_of: :logout_init_log, dependent: :nullify
  end
end
