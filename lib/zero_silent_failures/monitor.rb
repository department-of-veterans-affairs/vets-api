# frozen_string_literal: true

module ZeroSilentFailures
  class Monitor
    attr_accessor :function, :file

    def initialize(service, user_account_uuid = nil)
      @service = service
      @user_account_uuid = user_account_uuid ?: current_user.user_account_uuid
    end

    def log_silent_failure(additional_context)
      statsd = 'silent_failure'
      message = 'Silent failure!'

      StatsD.increment(statsd, tags: [service:, function:])
      Rails.error(message, {
        statsd:,
        service:,
        function:,
        file:,
        user_account_uuid:,
        additional_context:
      })
    end

    def log_silent_failure_avoided(additional_context, email_confirmed: false)
      statsd = 'silent_failure_avoided'
      message = 'Silent failure avoided'

      unless email_confirmed
        statsd = "#{statsd}_no_confirmation"
        message = "#{message} (no confirmation)"
      end

      StatsD.increment(statsd, tags: [service:, function:])
      Rails.error(message, {
        statsd:,
        service:,
        function:,
        file:,
        user_account_uuid:,
        additional_context:
      })
    end

    private

    attr_reader :service, :user_account_uuid

    def set_caller
      if !(function && file)
        failure_at = caller(2,1)

      end
    end

    def clear_caller
      function = nil
      file = nil
    end

  end
end
