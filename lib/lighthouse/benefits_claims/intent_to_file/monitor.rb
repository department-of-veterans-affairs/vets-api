# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module BenefitsClaims
  module IntentToFile
    class Monitor < ::ZeroSilentFailures::Monitor
      STATSD_KEY_PREFIX = 'worker.lighthouse.create_itf_async'

      def initialize
        super('pension-itf')
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
