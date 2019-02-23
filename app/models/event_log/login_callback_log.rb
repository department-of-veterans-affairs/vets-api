# frozen_string_literal: true

module EventLog
  class LoginCallbackLog < Log
    belongs_to :login_init_log, foreign_key: :event_log_id, inverse_of: :login_callback_log
  end
end
