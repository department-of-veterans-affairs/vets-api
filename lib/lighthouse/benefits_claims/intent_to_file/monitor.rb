# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module BenefitsClaims
  module IntentToFile
    class Monitor < ::ZeroSilentFailures::Monitor
      STATSD_KEY_PREFIX = 'worker.lighthouse.create_itf_async'
      STATSD_V1_KEY_PREFIX = 'worker.lighthouse.create_itf.v1'

      def initialize
        super('pension-itf')
      end

      # This metric does not include retries from failed attempts
      def track_create_itf_initiated(itf_type, form_start_date, user_account_uuid, form_id)
        tags = ["itf_type:#{itf_type}", 'version:v0']
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.initiated", tags:)
        context = {
          itf_type:,
          form_start_date:,
          user_account_uuid:
        }
        Rails.logger.info("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF initiated for form ##{form_id}",
                          context)
      end

      def track_create_itf_active_found(itf_type, form_start_date, user_account_uuid, itf_found)
        tags = ["itf_type:#{itf_type}", 'version:v0']
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.active_found", tags:)
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
        tags = ["itf_type:#{itf_type}", 'version:v0']
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.begun", tags:)
        context = {
          itf_type:,
          form_start_date:,
          user_account_uuid:
        }
        Rails.logger.info("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF begun", context)
      end

      def track_create_itf_success(itf_type, form_start_date, user_account_uuid)
        tags = ["itf_type:#{itf_type}", 'version:v0']
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.success", tags:)
        context = {
          itf_type:,
          form_start_date:,
          user_account_uuid:
        }
        Rails.logger.info("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF succeeded", context)
      end

      def track_create_itf_failure(itf_type, form_start_date, user_account_uuid, e)
        tags = ["itf_type:#{itf_type}", 'version:v0']
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{itf_type}.failure", tags:)
        context = {
          itf_type:,
          form_start_date:,
          user_account_uuid:,
          errors: e.try(:errors) || e&.message
        }
        Rails.logger.warn("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF failed", context)
      end

      def track_create_itf_exhaustion(itf_type, form, error)
        tags = ["form_id:#{form&.form_id}", "itf_type:#{itf_type}", 'version:v0']
        context = {
          error:,
          itf_type:,
          form_start_date: form&.created_at&.to_s,
          user_account_uuid: form&.user_account_id
        }
        log_silent_failure(context, form&.user_account_id, call_location: caller_locations.first)

        StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted", tags:)
        Rails.logger.error("Lighthouse::CreateIntentToFileJob create #{itf_type} ITF exhausted", context)
      end

      def track_missing_user_icn(form, error)
        tags = ["form_id:#{form&.form_id}", 'version:v0']
        StatsD.increment('user.icn.blank', tags:)
        context = {
          error: error.message,
          in_progress_form_id: form&.id,
          user_account_uuid: form&.user_account_id
        }
        Rails.logger.info('V0 InProgressFormsController async ITF user.icn is blank', context)
      end

      def track_missing_user_pid(form, error)
        tags = ["form_id:#{form&.form_id}", 'version:v0']
        StatsD.increment('user.participant_id.blank', tags:)
        context = {
          error: error.message,
          in_progress_form_id: form&.id,
          user_account_uuid: form&.user_account_id
        }
        Rails.logger.info('V0 InProgressFormsController async ITF user.participant_id is blank', context)
      end

      def track_missing_form(form, error)
        tags = ["form_id:#{form&.form_id}", 'version:v0']
        StatsD.increment('form.missing', tags:)
        context = {
          error: error.message,
          in_progress_form_id: form&.id,
          user_account_uuid: form&.user_account_id
        }
        Rails.logger.info('V0 InProgressFormsController async ITF form is missing', context)
      end

      def track_invalid_itf_type(form, error)
        tags = ["form_id:#{form&.form_id}", 'version:v0']
        StatsD.increment('itf.type.invalid', tags:)
        context = {
          error: error.message,
          in_progress_form_id: form&.id,
          user_account_uuid: form&.user_account_id
        }
        Rails.logger.info('V0 InProgressFormsController async ITF invalid ITF type', context)
      end

      # ITF controller metrics and logging

      def track_show_itf(form_id, itf_type, user_uuid)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}", 'version:v1']
        StatsD.increment("#{STATSD_V1_KEY_PREFIX}.#{itf_type}.show", tags:)
        context = { itf_type:, form_id:, user_uuid: }
        Rails.logger.info('IntentToFilesController ITF show', context)
      end

      def track_submit_itf(form_id, itf_type, user_uuid)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}", 'version:v1']
        StatsD.increment("#{STATSD_V1_KEY_PREFIX}.#{itf_type}.submit", tags:)
        context = { itf_type:, form_id:, user_uuid: }
        Rails.logger.info('IntentToFilesController ITF submit', context)
      end

      def track_itf_controller_error(method, form_id, itf_type, error)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}", "method:#{method}", 'version:v1']
        StatsD.increment('v1.itf.error', tags:)
        context = { error:, method:, form_id:, itf_type: }
        Rails.logger.error("IntentToFilesController #{itf_type} ITF controller error", context)
      end

      def track_missing_user_icn_itf_controller(method, form_id, itf_type, user_uuid, error)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}", "method:#{method}", 'version:v1']
        StatsD.increment('v1.user.icn.blank', tags:)
        context = { error:, method:, form_id:, itf_type:, user_uuid: }
        Rails.logger.info('IntentToFilesController ITF user.icn is blank', context)
      end

      def track_missing_user_pid_itf_controller(method, form_id, itf_type, user_uuid, error)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}", "method:#{method}", 'version:v1']
        StatsD.increment('v1.user.participant_id.blank', tags:)
        context = { error:, method:, form_id:, itf_type:, user_uuid: }
        Rails.logger.info('IntentToFilesController ITF user.participant_id is blank', context)
      end

      def track_invalid_itf_type_itf_controller(method, form_id, itf_type, user_uuid, error)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}", "method:#{method}", 'version:v1']
        StatsD.increment('v1.itf.type.invalid', tags:)
        context = { error:, method:, form_id:, itf_type:, user_uuid: }
        Rails.logger.info('IntentToFilesController ITF invalid ITF type', context)
      end
    end
  end
end
