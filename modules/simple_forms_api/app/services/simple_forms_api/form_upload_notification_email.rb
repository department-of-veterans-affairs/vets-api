# frozen_string_literal: true

module SimpleFormsApi
  class FormUploadNotificationEmail
    attr_reader :form_number, :form_name, :first_name, :email, :date_submitted, :confirmation_number,
                :lighthouse_updated_at, :notification_type

    template_root = Settings.vanotify.services.va_gov.template_id
    TEMPLATE_IDS = {
      confirmation: template_root.form_upload_confirmation_email,
      error: template_root.form_upload_error_email,
      received: template_root.form_upload_received_email
    }.freeze

    SUPPORTED_FORMS = %w[21-0779 21-509 21P-0518-1 21P-0516-1].freeze

    def initialize(config, notification_type:)
      @notification_type = notification_type

      check_missing_keys(config)
      check_if_form_is_supported(config)

      @form_number = config[:form_number]
      @form_name = config[:form_name]
      @first_name = config[:first_name]
      @email = config[:email]
      @date_submitted = config[:date_submitted]
      @confirmation_number = config[:confirmation_number]
      @lighthouse_updated_at = config[:lighthouse_updated_at]
    end

    def send(at: nil)
      template_id = TEMPLATE_IDS[notification_type]
      return unless template_id

      sent_to_va_notify = if at
                            enqueue_email(at, template_id)
                          else
                            send_email_now(template_id)
                          end
      StatsD.increment('silent_failure', tags: statsd_tags) if error_notification? && !sent_to_va_notify
    end

    private

    def check_missing_keys(config)
      all_keys = %i[form_number form_name first_name email date_submitted confirmation_number]

      missing_keys = all_keys.select { |key| config[key].nil? || config[key].to_s.strip.empty? }

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

    def send_email_now(template_id)
      VANotify::EmailJob.perform_async(
        email,
        template_id,
        get_personalization,
        Settings.vanotify.services.va_gov.api_key,
        { callback_metadata: { notification_type:, form_number:, statsd_tags: } }
      )
    end

    def enqueue_email(at, template_id)
      VANotify::EmailJob.perform_at(
        at,
        email,
        template_id,
        get_personalization,
        Settings.vanotify.services.va_gov.api_key,
        { callback_metadata: { notification_type:, form_number:, statsd_tags: } }
      )
    end

    def get_personalization
      {
        'first_name' => first_name&.titleize,
        'form_number' => form_number,
        'form_name' => form_name,
        'date_submitted' => date_submitted,
        'confirmation_number' => confirmation_number
      }.tap do |personalization|
        personalization['lighthouse_updated_at'] = lighthouse_updated_at if lighthouse_updated_at
      end
    end

    def statsd_tags
      { 'service' => 'veteran-facing-forms', 'function' => "#{form_number} form upload submission to Lighthouse" }
    end

    def error_notification?
      notification_type == :error
    end
  end
end
