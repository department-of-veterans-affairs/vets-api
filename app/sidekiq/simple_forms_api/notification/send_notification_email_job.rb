# frozen_string_literal: true

module SimpleFormsApi
  module Notification
    class SendNotificationEmailJob
      include Sidekiq::Job

      sidekiq_options retry: 10

      HOUR_TO_SEND_NOTIFICATIONS = 9

      attr_reader :notification_type, :form_number, :confirmation_number, :date_submitted, :lighthouse_updated_at

      def perform(notification_type:, form_data:, form_submission_attempt:)
        @notification_type = notification_type
        @form_number = form_data[:form_number]
        @confirmation_number = form_data[:benefits_intake_uuid]
        @date_submitted = form_submission_attempt.created_at.strftime('%B %d, %Y')
        @lighthouse_updated_at = form_submission_attempt.lighthouse_updated_at&.strftime('%B %d, %Y')

        if SimpleFormsApi::FormUploadNotificationEmail::SUPPORTED_FORMS.include? form_number
          form_upload_notification_email(form_data)
        else
          notification_email(form_data)
        end
      end

      private

      def form_upload_notification_email(form_data)
        config = {
          form_number:,
          form_name: form_data[:form_name],
          first_name: form_data.dig(:form_data, :full_name, :first),
          email: form_data.dig(:form_data, :email),
          date_submitted:,
          confirmation_number:,
          lighthouse_updated_at:
        }

        SimpleFormsApi::FormUploadNotificationEmail.new(
          config,
          notification_type:
        ).send(at: time_to_send)
      end

      def notification_email(form_data)
        config = {
          form_data:,
          form_number:,
          confirmation_number:,
          date_submitted:,
          lighthouse_updated_at:
        }

        SimpleFormsApi::NotificationEmail.new(
          config,
          notification_type:,
          user_account:
        ).send(at: time_to_send)
      end

      def time_to_send
        now = Time.now.in_time_zone('Eastern Time (US & Canada)')
        if now.hour < HOUR_TO_SEND_NOTIFICATIONS
          now.change(hour: HOUR_TO_SEND_NOTIFICATIONS,
                     min: 0)
        else
          now.tomorrow.change(
            hour: HOUR_TO_SEND_NOTIFICATIONS, min: 0
          )
        end
      end
    end
  end
end
