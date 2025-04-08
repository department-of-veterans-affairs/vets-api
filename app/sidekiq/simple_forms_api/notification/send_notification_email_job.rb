# frozen_string_literal: true

module SimpleFormsApi
  module Notification
    class SendNotificationEmailJob
      include Sidekiq::Job

      sidekiq_options retry: 10, backtrace: true

      HOUR_TO_SEND_NOTIFICATIONS = 9

      def perform(benefits_intake_uuid, form_number)
        @benefits_intake_uuid = benefits_intake_uuid
        @form_number = form_number
        @user_account = form_submission_attempt.user_account
        @form_submission = form_submission_attempt.form_submission

        return unless valid_notification?

        send_email
      rescue => e
        handle_exception(e)
      end

      private

      attr_accessor :user_account, :form_number, :form_submission

      def valid_notification?
        form_submission_attempt.failure? || form_submission_attempt.vbms?
      end

      def notification_type
        if form_submission_attempt.failure?
          :error
        elsif form_submission_attempt.vbms?
          :received
        end
      end

      def form_submission_attempt
        @form_submission_attempt ||= FormSubmissionAttempt.find_by(benefits_intake_uuid: @benefits_intake_uuid) ||
                                     raise_not_found_error('FormSubmissionAttempt', @benefits_intake_uuid)
      end

      def raise_not_found_error(resource, id)
        raise ActiveRecord::RecordNotFound, "#{resource} #{id} not found"
      end

      def config
        {
          form_data: JSON.parse(form_submission.form_data.presence || '{}'),
          form_number:,
          confirmation_number: @benefits_intake_uuid,
          date_submitted: form_submission_attempt.created_at.strftime('%B %d, %Y'),
          lighthouse_updated_at: form_submission_attempt.lighthouse_updated_at&.strftime('%B %d, %Y')
        }
      end

      def form_upload_supported?
        SimpleFormsApi::Notification::FormUploadEmail::SUPPORTED_FORMS.include?(form_number)
      end

      def form_upload_notification_email
        SimpleFormsApi::Notification::FormUploadEmail.new(config, notification_type:)
      end

      def notification_email
        SimpleFormsApi::Notification::Email.new(
          config,
          notification_type:,
          user_account:
        )
      end

      def time_to_send
        now = Time.zone.now.in_time_zone('Eastern Time (US & Canada)')
        target_time = now.change(hour: HOUR_TO_SEND_NOTIFICATIONS, min: 0)

        now.hour < HOUR_TO_SEND_NOTIFICATIONS ? target_time : target_time.tomorrow
      end

      def send_email
        email = form_upload_supported? ? form_upload_notification_email : notification_email

        email.send(at: time_to_send)
      end

      def statsd_tags
        { 'service' => 'veteran-facing-forms', 'function' => "#{form_number} form submission to Lighthouse" }
      end

      def handle_exception(e)
        Rails.logger.error(
          'Error sending simple forms notification email',
          message: e.message,
          notification_type:,
          confirmation_number: config&.dig(:confirmation_number)
        )

        StatsD.increment('silent_failure', tags: statsd_tags) if notification_type == :error
      end
    end
  end
end
