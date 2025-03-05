# frozen_string_literal: true

require_relative 'notification/parsing_utils'

# TODO: Delete this file after SimpleFormsApi::Notification::Email is in place.
module SimpleFormsApi
  class NotificationEmail
    attr_reader :form_number, :confirmation_number, :date_submitted, :expiration_date, :lighthouse_updated_at,
                :notification_type, :user, :user_account, :form_data

    include SimpleFormsApi::Notification::ParsingUtils

    TEMPLATE_IDS = {
      'vba_21_0845' => {
        confirmation: Settings.vanotify.services.va_gov.template_id.form21_0845_confirmation_email,
        error: Settings.vanotify.services.va_gov.template_id.form21_0845_error_email,
        received: Settings.vanotify.services.va_gov.template_id.form21_0845_received_email
      },
      'vba_21p_0847' => {
        confirmation: Settings.vanotify.services.va_gov.template_id.form21p_0847_confirmation_email,
        error: Settings.vanotify.services.va_gov.template_id.form21p_0847_error_email,
        received: Settings.vanotify.services.va_gov.template_id.form21p_0847_received_email
      },
      'vba_21_0966' => {
        confirmation: Settings.vanotify.services.va_gov.template_id.form21_0966_confirmation_email,
        error: Settings.vanotify.services.va_gov.template_id.form21_0966_error_email,
        received: Settings.vanotify.services.va_gov.template_id.form21_0966_received_email
      },
      'vba_21_0966_intent_api' => {
        received: Settings.vanotify.services.va_gov.template_id.form21_0966_itf_api_received_email
      },
      'vba_21_0972' => {
        confirmation: Settings.vanotify.services.va_gov.template_id.form21_0972_confirmation_email,
        error: Settings.vanotify.services.va_gov.template_id.form21_0972_error_email,
        received: Settings.vanotify.services.va_gov.template_id.form21_0972_received_email
      },
      'vba_21_4142' => {
        confirmation: Settings.vanotify.services.va_gov.template_id.form21_4142_confirmation_email,
        error: Settings.vanotify.services.va_gov.template_id.form21_4142_error_email,
        received: Settings.vanotify.services.va_gov.template_id.form21_4142_received_email
      },
      'vba_21_10210' => {
        confirmation: Settings.vanotify.services.va_gov.template_id.form21_10210_confirmation_email,
        error: Settings.vanotify.services.va_gov.template_id.form21_10210_error_email,
        received: Settings.vanotify.services.va_gov.template_id.form21_10210_received_email
      },
      'vba_20_10206' => {
        confirmation: Settings.vanotify.services.va_gov.template_id.form20_10206_confirmation_email,
        error: Settings.vanotify.services.va_gov.template_id.form20_10206_error_email,
        received: Settings.vanotify.services.va_gov.template_id.form20_10206_received_email
      },
      'vba_20_10207' => {
        confirmation: Settings.vanotify.services.va_gov.template_id.form20_10207_confirmation_email,
        error: Settings.vanotify.services.va_gov.template_id.form20_10207_error_email,
        received: Settings.vanotify.services.va_gov.template_id.form20_10207_received_email
      },
      'vba_40_0247' => {
        confirmation: Settings.vanotify.services.va_gov.template_id.form40_0247_confirmation_email,
        error: Settings.vanotify.services.va_gov.template_id.form40_0247_error_email,
        received: nil
      },
      'vba_40_10007' => {
        confirmation: nil,
        error: Settings.vanotify.services.va_gov.template_id.form40_10007_error_email,
        received: nil
      },
      'vba_26_4555' => {
        confirmation: Settings.vanotify.services.va_gov.template_id.form26_4555_confirmation_email,
        rejected: Settings.vanotify.services.va_gov.template_id.form26_4555_rejected_email,
        duplicate: Settings.vanotify.services.va_gov.template_id.form26_4555_duplicate_email
      }
    }.freeze
    SUPPORTED_FORMS = TEMPLATE_IDS.keys

    def initialize(config, notification_type: :confirmation, user: nil, user_account: nil)
      @notification_type = notification_type

      check_missing_keys(config)
      check_if_form_is_supported(config)

      @form_data = config[:form_data]
      @form_number = config[:form_number]
      @confirmation_number = config[:confirmation_number]
      @date_submitted = config[:date_submitted]
      @expiration_date = config[:expiration_date]
      @lighthouse_updated_at = config[:lighthouse_updated_at]
      @user = user
      @user_account = user_account
    end

    def send(at: nil)
      return unless flipper?

      template_id = TEMPLATE_IDS[form_number][notification_type]
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
      email = contact_info[:email]
      first_name = contact_info[:first_name]

      # async job and form data includes email
      if email && first_name
        async_job_with_form_data(email, first_name, at, template_id)
      # async job and we have a UserAccount
      elsif user_account
        async_job_with_user_account(user_account, at, template_id)
      end
    end

    def async_job_with_form_data(email, first_name, at, template_id)
      if Flipper.enabled?(:simple_forms_notification_callbacks)
        VANotify::EmailJob.perform_at(
          at,
          email,
          template_id,
          get_personalization(first_name),
          *email_args
        )
      else
        VANotify::EmailJob.perform_at(
          at,
          email,
          template_id,
          get_personalization(first_name)
        )
      end
    end

    def async_job_with_user_account(user_account, at, template_id)
      first_name = get_first_name_from_user_account
      return unless first_name

      if Flipper.enabled?(:simple_forms_notification_callbacks)
        VANotify::UserAccountJob.perform_at(
          at,
          user_account.id,
          template_id,
          get_personalization(first_name),
          *email_args
        )
      else
        VANotify::UserAccountJob.perform_at(
          at,
          user_account.id,
          template_id,
          get_personalization(first_name)
        )
      end
    end

    def send_email_now(template_id)
      email = contact_info[:email]
      first_name = contact_info[:first_name] || get_first_name_from_user

      return unless first_name && email

      VANotify::EmailJob.perform_async(
        email,
        template_id,
        get_personalization(first_name)
      )
    end

    def get_first_name_from_user_account
      mpi_response = MPI::Service.new.find_profile_by_identifier(identifier_type: 'ICN', identifier: user_account.icn)
      if mpi_response
        error = mpi_response.error
        Rails.logger.error('MPI response error', { error: }) if error

        first_name = mpi_response.profile&.given_names&.first
        Rails.logger.error('MPI profile missing first_name') unless first_name

        first_name
      end
    end

    def get_first_name_from_user
      Rails.logger.error('First name not found in user profile') unless user&.first_name
      user&.first_name
    end

    def get_personalization(first_name)
      personalization = if @form_number.start_with? 'vba_21_0966'
                          default_personalization(first_name).merge(form21_0966_personalization)
                        else
                          default_personalization(first_name)
                        end
      personalization.except!('lighthouse_updated_at') unless lighthouse_updated_at
      personalization.except!('confirmation_number') unless confirmation_number
      personalization
    end

    # personalization hash shared by all simple form confirmation emails
    def default_personalization(first_name)
      {
        'first_name' => first_name&.titleize,
        'date_submitted' => date_submitted,
        'confirmation_number' => confirmation_number,
        'lighthouse_updated_at' => lighthouse_updated_at
      }
    end

    def form21_0966_personalization
      intent_to_file_benefits, intent_to_file_benefits_links = get_intent_to_file_benefits_variables
      {
        'intent_to_file_benefits' => intent_to_file_benefits,
        'intent_to_file_benefits_links' => intent_to_file_benefits_links,
        'itf_api_expiration_date' => expiration_date
      }
    end

    def get_intent_to_file_benefits_variables
      benefits = @form_data['benefit_selection']
      if benefits['compensation'] && benefits['pension']
        ['disability compensation and Veterans pension benefits',
         '[File for disability compensation (VA Form 21-526EZ)]' \
         '(https://www.va.gov/disability/file-disability-claim-form-21-526ez/introduction) and [Apply for Veterans ' \
         'Pension benefits (VA Form 21P-527EZ)](https://www.va.gov/find-forms/about-form-21p-527ez/)']
      elsif benefits['compensation']
        ['disability compensation',
         '[File for disability compensation (VA Form 21-526EZ)](https://www.va.gov/disability/file-disability-claim-form-21-526ez/introduction)']
      elsif benefits['pension']
        ['Veterans pension benefits',
         '[Apply for Veterans Pension benefits (VA Form 21P-527EZ)](https://www.va.gov/find-forms/about-form-21p-527ez/)']
      elsif benefits['survivor']
        ['survivors pension benefits',
         '[Apply for DIC, Survivors Pension, and/or Accrued Benefits (VA Form 21P-534EZ)](https://www.va.gov/find-forms/about-form-21p-534ez/)']
      end
    end

    def form40_10007_first_name
      applicant_relationship = form_data.dig('application', 'applicant', 'applicant_relationship_to_claimant')

      if applicant_relationship == 'Self'
        form_data.dig('application', 'claimant', 'name', 'first')
      else
        form_data.dig('application', 'applicant', 'name', 'first')
      end
    end

    def email_args
      [
        Settings.vanotify.services.va_gov.api_key,
        { callback_metadata: { notification_type:, form_number:, confirmation_number:, statsd_tags: } }
      ]
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
