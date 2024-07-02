# frozen_string_literal: true

module BenefitsClaims
  module IntentToFile
    class Monitor
      STATSD_KEY_PREFIX = 'worker.lighthouse.create_itf_async'

      def track_create_itf_begun(itf_type, form_start_date, user_account_uuid)
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.begun")
        Rails.logger.info("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF begun", {
                            itf_type:,
                            form_start_date:,
                            user_account_uuid:
                          })
      end

      def track_create_itf_success(itf_type, form_start_date, user_account_uuid)
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.success")
        Rails.logger.info("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF succeeded", {
                            itf_type:,
                            form_start_date:,
                            user_account_uuid:
                          })
      end

      def track_create_itf_failure(itf_type, form_start_date, user_account_uuid, e)
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.failure")
        Rails.logger.warn("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF failed", {
                            itf_type:,
                            form_start_date:,
                            user_account_uuid:,
                            message: e&.message
                          })
      end

      def track_create_itf_exhaustion(itf_type, form_start_date, user_account_uuid, error)
        StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")
        Rails.logger.error("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF exhausted", {
                             error:,
                             itf_type:,
                             form_start_date:,
                             user_account_uuid:
                           })
      end
    end
  end
end
