# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module BenefitsClaims
  module IntentToFile
    class Monitor < ::ZeroSilentFailures::Monitor
      STATSD_KEY_PREFIX = 'worker.lighthouse.create_itf_async'

      def initialize
        super('pension-itf')
      end

      # This metric does not include retries from failed attempts
      def track_create_itf_initiated(itf_type, form_start_date, user_account_uuid, form_id)
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.initiated")
        context = {
          itf_type:,
          form_start_date:,
          user_account_uuid:
        }
        Rails.logger.info("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF initiated for form ##{form_id}",
                          context)
      end

      def track_create_itf_active_found(itf_type, form_start_date, user_account_uuid, itf_found)
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.active_found")
        context = {
          itf_type:,
          itf_created: itf_found&.dig('data', 'attributes', 'creationDate'),
          itf_expires: itf_found&.dig('data', 'attributes', 'expirationDate'),
          form_start_date:,
          user_account_uuid:
        }
        Rails.logger.info("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF active record found", context)
      end

      # This metric includes retries from failed attempts
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

      def track_create_itf_exhaustion(itf_type, form, error)
        context = {
          error:,
          itf_type:,
          form_start_date: form&.created_at&.to_s,
          user_account_uuid: form&.user_account_id
        }
        log_silent_failure(context, form&.user_account_id, call_location: caller_locations.first)

        StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")
        Rails.logger.error("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF exhausted", context)
      end

      def track_missing_user_icn(form, error)
        StatsD.increment('user.icn.blank')
        context = {
          error: error.message,
          in_progress_form_id: form&.id,
          user_account_uuid: form&.user_account_id
        }
        Rails.logger.info('V0 InProgressFormsController async ITF user.icn is blank', context)
      end

      def track_missing_user_pid(form, error)
        StatsD.increment('user.participant_id.blank')
        context = {
          error: error.message,
          in_progress_form_id: form&.id,
          user_account_uuid: form&.user_account_id
        }
        Rails.logger.info('V0 InProgressFormsController async ITF user.participant_id is blank', context)
      end

      def track_missing_form(form, error)
        StatsD.increment('form.missing')
        context = {
          error: error.message,
          in_progress_form_id: form&.id,
          user_account_uuid: form&.user_account_id
        }
        Rails.logger.info('V0 InProgressFormsController async ITF form is missing', context)
      end

      def track_invalid_itf_type(form, error)
        StatsD.increment('itf.type.invalid')
        context = {
          error: error.message,
          in_progress_form_id: form&.id,
          user_account_uuid: form&.user_account_id
        }
        Rails.logger.info('V0 InProgressFormsController async ITF invalid ITF type', context)
      end

      # ITF controller metrics and logging

      def track_show_itf(form_id, itf_type, user_uuid)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}"]
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.show", tags:)
        context = { itf_type:, form_id:, user_uuid: }
        Rails.logger.info('V0 IntentToFilesController ITF show', context)
      end

      def track_submit_itf(form_id, itf_type, user_uuid)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}"]
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.submit", tags:)
        context = { itf_type:, form_id:, user_uuid: }
        Rails.logger.info('V0 IntentToFilesController ITF submit', context)
      end

      def track_missing_user_icn_itf_controller(method, form_id, itf_type, user_uuid, error)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}", "method:#{method}"]
        StatsD.increment('user.icn.blank', tags:)
        context = { error:, method:, form_id:, itf_type:, user_uuid: }
        Rails.logger.info('V0 IntentToFilesController ITF user.icn is blank', context)
      end

      def track_missing_user_pid_itf_controller(method, form_id, itf_type, user_uuid, error)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}", "method:#{method}"]
        StatsD.increment('user.participant_id.blank', tags:)
        context = { error:, method:, form_id:, itf_type:, user_uuid: }
        Rails.logger.info('V0 IntentToFilesController ITF user.participant_id is blank', context)
      end

      def track_invalid_itf_type_itf_controller(method, form_id, itf_type, user_uuid, error)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}", "method:#{method}"]
        StatsD.increment('itf.type.invalid', tags:)
        context = { error:, method:, form_id:, itf_type:, user_uuid: }
        Rails.logger.info('V0 IntentToFilesController ITF invalid ITF type', context)
      end
    end
  end
end
