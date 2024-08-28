# frozen_string_literal: true

module BenefitsClaims
  module PersonProxyAdd
    class Monitor
      STATSD_KEY_PREFIX = 'worker.lighthouse.pension_create_pid_for_icn'
      DEFAULT_LOGGER_MESSAGE = 'Add person proxy by icn'

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
