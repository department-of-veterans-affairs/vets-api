# frozen_string_literal: true

module BenefitsClaims
  module IntentToFile
    class Monitor
      STATSD_KEY_PREFIX = 'worker.lighthouse.create_itf_async'

      def track_create_itf_begun(itf_type, form_start_date, user_account_uuid)
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.begun")
        context = {
          itf_type:,
          form_start_date:,
          user_account_uuid:
        }
        Rails.logger.info("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF begun", context)
      end

      def track_create_itf_success(itf_type, form_start_date, user_account_uuid)
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.success")
        context = {
          itf_type:,
          form_start_date:,
          user_account_uuid:
        }
        Rails.logger.info("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF succeeded", context)
      end

      def track_create_itf_failure(itf_type, form_start_date, user_account_uuid, e)
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.failure")
        context = {
          itf_type:,
          form_start_date:,
          user_account_uuid:,
          errors: e.try(:errors) || e&.message
        }
        Rails.logger.warn("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF failed", context)
      end

      def track_create_itf_exhaustion(itf_type, form_start_date, user_account_uuid, error)
        StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")
        context = {
          error:,
          itf_type:,
          form_start_date:,
          user_account_uuid:
        }
        Rails.logger.error("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF exhausted", context)
      end
    end
  end
end
