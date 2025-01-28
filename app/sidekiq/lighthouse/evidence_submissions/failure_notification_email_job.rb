# frozen_string_literal: true

require 'sidekiq'
require 'lighthouse/benefits_documents/constants'
require 'lighthouse/benefits_documents/utilities/helpers'

module Lighthouse
  module EvidenceSubmissions
    class FailureNotificationEmailJob
      include Sidekiq::Job
      include SentryLogging

      sidekiq_options retry: false, unique_for: 30.minutes
      NOTIFY_SETTINGS = Settings.vanotify.services.benefits_management_tools
      MAILER_TEMPLATE_ID = NOTIFY_SETTINGS.template_id.evidence_submission_failure_email
      # TODO: need to add statsd logic
      # STATSD_KEY_PREFIX = ''

      def perform
        return unless should_perform?

        send_failed_evidence_submissions

        nil
      end

      def should_perform?
        failed_uploads.present?
      end

      # Fetches FAILED evidence submission records for BenefitsDocuments that dont have a va_notify_date
      def failed_uploads
        @failed_uploads ||= EvidenceSubmission.va_notify_email_not_queued
      end

      def notify_client
        VaNotify::Service.new(NOTIFY_SETTINGS.api_key, { callback_klass: 'BenefitsDocuments::VANotifyEmailStatusCallback' })
      end

      def send_failed_evidence_submissions
        failed_uploads.each do |upload|
          personalisation =
            create_personalisation(
              JSON.parse(upload.template_metadata_ciphertext)['personalisation']
            )
          # NOTE: The file_name in the personalisation that is passed in is obscured
          response = notify_client.send_email(
            recipient_identifier: { id_value: upload.user_account.icn, id_type: 'ICN' },
            template_id: MAILER_TEMPLATE_ID,
            personalisation:
          )
          record_email_send_success(upload, response)
        rescue => e
          record_email_send_failure(upload, e)
        end

        nil
      end

      # This will be used to send an upload failure email
      def create_personalisation(current_personalisation)
        {
          first_name: current_personalisation['first_name'],
          document_type: current_personalisation['document_type'],
          file_name: current_personalisation['obfuscated_file_name'],
          date_submitted: current_personalisation['date_submitted'],
          date_failed: current_personalisation['date_failed']
        }
      end

      def record_email_send_success(upload, response)
        upload.update(va_notify_id: response.id, va_notify_date: DateTime.now)
        message = "#{upload.job_class} va notify failure email queued"
        ::Rails.logger.info(message)
        StatsD.increment('silent_failure_avoided_no_confirmation',
                         tags: ['service:claim-status', "function: #{message}"])
      end

      def record_email_send_failure(upload, error)
        error_message = "#{upload.job_class} va notify failure email errored"
        ::Rails.logger.error(error_message, { message: error.message })
        StatsD.increment('silent_failure', tags: ['service:claim-status', "function: #{error_message}"])
        log_exception_to_sentry(error)
      end
    end
  end
end
