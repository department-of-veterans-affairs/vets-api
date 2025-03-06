# frozen_string_literal: true

module SimpleFormsApi
  module Notification
    class SendNotificationEmailJob
      include Sidekiq::Job

      sidekiq_options retry: 10, backtrace: true

      HOUR_TO_SEND_NOTIFICATIONS = 9

      attr_reader :notification_type, :config, :form_number

      def perform(args)
        @notification_type = args[:notification_type]
        @form_number = args[:form_number]
        @user_account_id = args[:user_account_id]
        @form_submission_attempt_id = args[:form_submission_attempt_id]
        @config = {
          form_data: JSON.parse(form_submission_attempt.form_submission.form_data || '{}'),
          form_number:,
          confirmation_number: form_submission_attempt.benefits_intake_uuid,
          date_submitted: form_submission_attempt.created_at.strftime('%B %d, %Y'),
          lighthouse_updated_at: form_submission_attempt.lighthouse_updated_at&.strftime('%B %d, %Y')
        }

        return send_form_upload_notification_email if form_supported?

        send_notification_email
      rescue => e
        handle_exception(e)
      end

      private

      def user_account
        @user_account ||= UserAccount.find(@user_account_id)
      end

      def form_submission_attempt
        @form_submission_attempt ||= FormSubmissionAttempt.find(@form_submission_attempt_id)
      end

      def form_supported?
        SimpleFormsApi::FormUploadNotificationEmail::SUPPORTED_FORMS.include? form_number
      end

      def send_form_upload_notification_email
        SimpleFormsApi::FormUploadNotificationEmail.new(config, notification_type:).send(at: time_to_send)
      end

      def send_notification_email
        SimpleFormsApi::NotificationEmail.new(config, notification_type:, user_account:).send(at: time_to_send)
      end

      def time_to_send
        now = Time.now.in_time_zone('Eastern Time (US & Canada)')
        if now.hour < HOUR_TO_SEND_NOTIFICATIONS
          now.change(hour: HOUR_TO_SEND_NOTIFICATIONS, min: 0)
        else
          now.tomorrow.change(hour: HOUR_TO_SEND_NOTIFICATIONS, min: 0)
        end
      end

      def statsd_tags
        { 'service' => 'veteran-facing-forms', 'function' => "#{form_number} form submission to Lighthouse" }
      end

      def handle_exception(e)
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
