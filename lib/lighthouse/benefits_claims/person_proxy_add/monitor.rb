# frozen_string_literal: true

module BenefitsClaims
  # add/retrieve a pid
  module PersonProxyAdd
    # monitoring functions
    class Monitor
      # statd prefix
      STATSD_KEY_PREFIX = 'worker.lighthouse.create_pid_for_icn'

      # default message
      DEFAULT_LOGGER_MESSAGE = 'Add person proxy by icn'

      # track job exhaustion for proxy add
      def track_proxy_add_exhaustion(form_type, form_start_date, user_account_uuid, error)
        StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")
        context = {
          error:,
          form_type:,
          form_start_date:,
          user_account_uuid:
        }
        Rails.logger.error("#{DEFAULT_LOGGER_MESSAGE} retries exhausted", context)
      end
    end
  end
end
