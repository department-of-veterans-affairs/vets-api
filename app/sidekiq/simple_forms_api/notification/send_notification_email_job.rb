# frozen_string_literal: true

module SimpleFormsApi
  module Notification
    class SendNotificationEmailJob
      include Sidekiq::Job

      sidekiq_options retry: 10, backtrace: true

      HOUR_TO_SEND_NOTIFICATIONS = 9

      attr_reader :form_submission_attempt, :notification_type, :config, :form_number, :user_account

      def perform(benefits_intake_uuid, form_number)
        @form_submission_attempt = FormSubmissionAttempt.find_by(benefits_intake_uuid:)
        @notification_type = get_notification_type
        @user_account = form_submission_attempt.user_account
        @form_number = form_number
        form_submission = form_submission_attempt.form_submission
        @config = {
          form_data: JSON.parse(form_submission.form_data || '{}'),
          form_number:,
          confirmation_number: form_submission_attempt.benefits_intake_uuid,
          date_submitted: form_submission_attempt.created_at.strftime('%B %d, %Y'),
          lighthouse_updated_at: form_submission_attempt.lighthouse_updated_at&.strftime('%B %d, %Y')
        }

        if SimpleFormsApi::FormUploadNotificationEmail::SUPPORTED_FORMS.include? form_number
          form_upload_notification_email
        else
          notification_email
        end
      rescue => e
        handle_exception(e)
      end

      private

      def form_upload_notification_email
        SimpleFormsApi::FormUploadNotificationEmail.new(config, notification_type:).send(at: time_to_send)
      end

      def notification_email
        SimpleFormsApi::NotificationEmail.new(
          config,
          notification_type:,
          user_account:
        ).send(at: time_to_send)
      end

      def time_to_send
        now = Time.now.in_time_zone('Eastern Time (US & Canada)')
        if now.hour < HOUR_TO_SEND_NOTIFICATIONS
          now.change(hour: HOUR_TO_SEND_NOTIFICATIONS, min: 0)
        else
          now.tomorrow.change(hour: HOUR_TO_SEND_NOTIFICATIONS, min: 0)
        end
      end

      def get_notification_type
        if form_submission_attempt.failure?
          :error
        elsif form_submission_attempt.vbms?
          :received
        end
      end

      def statsd_tags
        { 'service' => 'veteran-facing-forms', 'function' => "#{form_number} form submission to Lighthouse" }
      end

      def handle_exception(e)
        notification_type = get_notification_type
        Rails.logger.error(
          'Error sending simple forms notification email',
          message: e.message,
          notification_type:,
          confirmation_number: config[:confirmation_number]
        )
        StatsD.increment('silent_failure', tags: statsd_tags) if notification_type == :error
      end
    end
  end
end
