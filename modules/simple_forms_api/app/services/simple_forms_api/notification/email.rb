# frozen_string_literal: true

module SimpleFormsApi
  module Notification
    class Email
      attr_reader :form_number, :confirmation_number, :date_submitted, :expiration_date, :lighthouse_updated_at,
                  :notification_type, :user, :user_account, :form_data, :form_submission_attempt, :form

      TEMPLATE_IDS = YAML.load_file("#{__dir__}/template_ids.yml")
      SUPPORTED_FORMS = TEMPLATE_IDS.keys

      def initialize(config, form_submission_attempt, notification_type: :confirmation, user: nil, user_account: nil)
        @notification_type = notification_type

        check_missing_keys(config)
        check_if_form_is_supported(config)

        @form_data = config[:form_data]
        @form_number = config[:form_number]
        @confirmation_number = config[:confirmation_number]
        @date_submitted = config[:date_submitted]
        @expiration_date = config[:expiration_date]
        @lighthouse_updated_at = config[:lighthouse_updated_at]
        @form_submission_attempt = form_submission_attempt
        # We need this annoying cleaned_form_number for now because 21-0966 has an intent_api variant
        # vba_21_0966_intent_api becomes vba_21_0966
        cleaned_form_number = @form_number.gsub('_intent_api', '')
        @form = "SimpleFormsApi::#{cleaned_form_number.titleize.gsub(' ', '')}".constantize.new(@form_data)
        @user = user
        @user_account = user_account
      end

      def send(at: nil)
        return unless flipper?

        template_id = TEMPLATE_IDS[form_number][notification_type.to_s]
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
        all_keys = %i[form_data form_number date_submitted]
        all_keys << :confirmation_number if needs_confirmation_number?
        all_keys << :expiration_date if config[:form_number] == 'vba_21_0966_intent_api'

        missing_keys = all_keys.select { |key| config[key].nil? || config[key].to_s.strip.empty? }

        if missing_keys.any?
          StatsD.increment('silent_failure', tags: statsd_tags) if error_notification?
          raise ArgumentError, "Missing keys: #{missing_keys.join(', ')}"
        end
      end

      def check_if_form_is_supported(config)
        unless SUPPORTED_FORMS.include?(config[:form_number])
          StatsD.increment('silent_failure', tags: statsd_tags) if error_notification?
          raise ArgumentError, "Unsupported form: given form number was #{config[:form_number]}"
        end
      end

      def flipper?
        number = form_number
        number = 'vba_21_0966' if form_number.start_with? 'vba_21_0966'
        Flipper.enabled?(:"form#{number.gsub('vba_', '')}_confirmation_email")
      end

      def enqueue_email(at, template_id)
        email_from_form_data = form.notification_email_address

        # async job and form data includes email
        if email_from_form_data
          async_job_with_form_data(email_from_form_data, at, template_id)
        # async job and we have a UserAccount
        elsif user_account
          async_job_with_user_account(user_account, at, template_id)
        end
      end

      def async_job_with_form_data(email, at, template_id)
        VANotify::EmailJob.perform_at(
          at,
          email,
          template_id,
          get_personalization,
          Settings.vanotify.services.va_gov.api_key,
          { callback_metadata: { notification_type:, form_number:, statsd_tags: } }
        )
      end

      def async_job_with_user_account(user_account, at, template_id)
        VANotify::UserAccountJob.perform_at(
          at,
          user_account.id,
          template_id,
          get_personalization,
          Settings.vanotify.services.va_gov.api_key,
          { callback_metadata: { notification_type:, form_number:, statsd_tags: } }
        )
      end

      def send_email_now(template_id)
        email_address = form.notification_email_address || user&.email
        personalization = get_personalization

        if email_address && personalization
          VANotify::EmailJob.perform_async(
            email_address,
            template_id,
            personalization
          )
        end
      end

      def get_personalization
        SimpleFormsApi::Notification::Personalization.new(form:, form_submission_attempt:).to_hash
      end

      def statsd_tags
        { 'service' => 'veteran-facing-forms', 'function' => "#{form_number} form submission to Lighthouse" }
      end

      def error_notification?
        notification_type == :error
      end

      def needs_confirmation_number?
        # All email templates require confirmation_number except :duplicate for 26-4555 (SAHSHA)
        # Only 26-4555 supports the :duplicate notification_type
        notification_type != :duplicate
      end
    end
  end
end
