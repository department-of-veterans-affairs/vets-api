# frozen_string_literal: true

module SimpleFormsApi
  module Notification
    class FormUploadEmail
      attr_reader :form_number, :form_name, :confirmation_number, :date_submitted, :lighthouse_updated_at,
                  :notification_type, :template_id, :statsd_tags, :form_data

      template_root = Settings.vanotify.services.va_gov.template_id
      TEMPLATE_IDS = {
        confirmation: template_root.form_upload_confirmation_email,
        error: template_root.form_upload_error_email,
        received: template_root.form_upload_received_email
      }.freeze
      SUPPORTED_FORMS = %w[
        21P-4185
        21-651
        21-0304
        21-8960
        21P-4706c
        21-4140
        21P-4718a
        21-4193
        21-0788
        21-8951-2
        21-674b
        21-2680
        21-0779
        21-4192
        21-509
        21-686c
        21-8940
        21P-0516-1
        21P-0517-1
        21P-0518-1
        21P-0519C-1
        21P-0519S-1
        21P-530a
        21P-8049
        21P-535
        20-10208
      ].freeze

      def initialize(config, notification_type:)
        @notification_type = notification_type
        @template_id = TEMPLATE_IDS[notification_type]

        check_missing_keys(config)
        check_if_form_is_supported(config)

        @form_data = config[:form_data]
        @form_number = config[:form_number]
        @confirmation_number = config[:confirmation_number]
        @date_submitted = config[:date_submitted]
        @lighthouse_updated_at = config[:lighthouse_updated_at]
        @statsd_tags = {
          'service' => 'veteran-facing-forms',
          'function' => "#{form_number} form upload submission to Lighthouse"
        }
      end

      def send(at: nil)
        return unless template_id

        sent_to_va_notify = if at
                              enqueue_email(at)
                            else
                              send_email_now
                            end
        StatsD.increment('silent_failure', tags: statsd_tags) if error_notification? && !sent_to_va_notify
      end

      private

      def check_missing_keys(config)
        all_keys = %i[form_data form_number date_submitted confirmation_number]

        missing_keys = all_keys.select { |key| config[key].blank? }
        email = config.dig(:form_data, 'email')
        first_name = config.dig(:form_data, 'full_name', 'first')
        missing_keys << 'form_data: email' if email.blank?
        missing_keys << 'form_data: first_name' if first_name.blank?

        if missing_keys.any?
          StatsD.increment('silent_failure', tags: statsd_tags) if error_notification?
          raise ArgumentError, "Missing keys: #{missing_keys.join(', ')}"
        end
      end

      def check_if_form_is_supported(config)
        unless SUPPORTED_FORMS.include?(config[:form_number])
          StatsD.increment('silent_failure', tags: statsd_tags) if error_notification?
          raise ArgumentError, "Attempted to upload unsupported form: given form number was #{config[:form_number]}"
        end
      end

      def send_email_now
        VANotify::EmailJob.perform_async(
          form_data['email'],
          template_id,
          get_personalization,
          *email_args
        )
      end

      def enqueue_email(at)
        VANotify::EmailJob.perform_at(
          at,
          form_data['email'],
          template_id,
          get_personalization,
          *email_args
        )
      end

      def email_args
        [
          Settings.vanotify.services.va_gov.api_key,
          { callback_metadata: { notification_type:, form_number:, confirmation_number:, statsd_tags: } }
        ]
      end

      def get_personalization
        {
          'first_name' => form_data.dig('full_name', 'first')&.titleize,
          'form_number' => form_number,
          'form_name' => form_data['form_name'],
          'date_submitted' => date_submitted,
          'confirmation_number' => confirmation_number
        }.tap do |personalization|
          personalization['lighthouse_updated_at'] = lighthouse_updated_at if lighthouse_updated_at
        end
      end

      def error_notification?
        notification_type == :error
      end
    end
  end
end
