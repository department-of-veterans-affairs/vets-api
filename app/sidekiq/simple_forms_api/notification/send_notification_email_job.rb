# frozen_string_literal: true

module SimpleFormsApi
  module Notification
    class SendNotificationEmailJob
      include Sidekiq::Job

      sidekiq_options retry: 10, backtrace: true

      HOUR_TO_SEND_NOTIFICATIONS = 9

      def perform(args)
        raise ArgumentError, "Expected a Hash, got #{args.class}" unless args.is_a?(Hash)

        @notification_type = args[:notification_type]
        @form_number = args[:form_number]
        @user_account_id = args[:user_account_id]
        @form_submission_attempt_id = args[:form_submission_attempt_id]

        return handle_exception(StandardError.new('Missing required arguments')) if missing_required_arguments?

        @config = build_config

        return send_form_upload_notification_email if form_supported?

        send_notification_email
      rescue => e
        handle_exception(e)
      end

      private

      def user_account
        @user_account ||= UserAccount.find_by(id: @user_account_id) || (raise ActiveRecord::RecordNotFound,
                                                                              "UserAccount #{@user_account_id} not found")
      end

      def form_submission_attempt
        @form_submission_attempt ||= FormSubmissionAttempt.find_by(id: @form_submission_attempt_id) || (raise ActiveRecord::RecordNotFound,
                                                                                                              "FormSubmissionAttempt #{@form_submission_attempt_id} not found")
      end

      def form_supported?
        SimpleFormsApi::FormUploadNotificationEmail::SUPPORTED_FORMS.include?(@form_number)
      end

      def send_form_upload_notification_email
        SimpleFormsApi::FormUploadNotificationEmail.new(@config,
                                                        notification_type: @notification_type).send(at: time_to_send)
      end

      def send_notification_email
        SimpleFormsApi::NotificationEmail.new(@config, notification_type: @notification_type,
                                                       user_account:).send(at: time_to_send)
      end

      def time_to_send
        now = Time.zone.now.in_time_zone('Eastern Time (US & Canada)')
        target_time = now.change(hour: HOUR_TO_SEND_NOTIFICATIONS, min: 0)

        now.hour < HOUR_TO_SEND_NOTIFICATIONS ? target_time : target_time.tomorrow
      end

      def statsd_tags
        { 'service' => 'veteran-facing-forms', 'function' => "#{@form_number} form submission to Lighthouse" }
      end

      def handle_exception(e)
        Rails.logger.error(
          {
            error: 'Error sending simple forms notification email',
            message: e.message,
            notification_type: @notification_type.to_s,
            confirmation_number: @config&.dig(:confirmation_number)
          }.to_json
        )

        StatsD.increment('silent_failure', tags: statsd_tags) if @notification_type == :error
      end

      def missing_required_arguments?
        [@notification_type, @form_number, @user_account_id, @form_submission_attempt_id].any?(&:nil?)
      end

      def build_config
        attempt = form_submission_attempt
        {
          form_data: JSON.parse(attempt.form_submission.form_data.presence || '{}'),
          form_number: @form_number,
          confirmation_number: attempt.benefits_intake_uuid,
          date_submitted: attempt.created_at.strftime('%B %d, %Y'),
          lighthouse_updated_at: attempt.lighthouse_updated_at&.strftime('%B %d, %Y')
        }
      end
    end
  end
end
