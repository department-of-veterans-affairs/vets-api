# frozen_string_literal: true

module SimpleFormsApi
  module Notification
    class SendNotificationEmailJob
      include Sidekiq::Job

      sidekiq_options retry: 10

      HOUR_TO_SEND_NOTIFICATIONS = 9

      attr_reader :notification_type, :form_number, :confirmation_number, :date_submitted, :lighthouse_updated_at,
                  :user_account

      def perform(notification_type:, form_submission_attempt:, user_account:)
        @notification_type = notification_type
        @form_number = V1::UploadsController::FORM_NUMBER_MAP[form_submission_attempt.form_submission.form_type]
        @confirmation_number = form_submission_attempt.benefits_intake_uuid
        @date_submitted = form_submission_attempt.created_at.strftime('%B %d, %Y')
        @lighthouse_updated_at = form_submission_attempt.lighthouse_updated_at&.strftime('%B %d, %Y')
        @user_account = user_account

        form_data = JSON.parse(form_submission_attempt.form_submission.form_data)
        notification_email(form_data)
      end

      private

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
