# frozen_string_literal: true

module EventLog
  class LoginInitLog < Log
    has_one :login_callback_log, foreign_key: :event_log_id, inverse_of: :login_init_log, dependent: :nullify
  end
end
