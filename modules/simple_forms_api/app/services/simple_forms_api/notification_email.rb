# frozen_string_literal: true

module SimpleFormsApi
  class NotificationEmail
    attr_reader :form_number, :confirmation_number, :date_submitted, :lighthouse_updated_at, :notification_type, :user,
                :form_data

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
        error: nil,
        received: nil
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
        error: nil,
        received: nil
      }
    }.freeze
    SUPPORTED_FORMS = TEMPLATE_IDS.keys

    def initialize(config, notification_type: :confirmation, user: nil)
      check_missing_keys(config)

      @form_data = config[:form_data]
      incoming_form_number = config[:form_number]
      @form_number = if TEMPLATE_IDS.keys.include?(incoming_form_number)
                       incoming_form_number
                     else
                       SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP[incoming_form_number]
                     end
      @confirmation_number = config[:confirmation_number]
      @date_submitted = config[:date_submitted]
      @lighthouse_updated_at = config[:lighthouse_updated_at]
      @notification_type = notification_type
      @user = user
    end

    def send(at: nil)
      return unless SUPPORTED_FORMS.include?(form_number)
      return unless flipper?

      template_id = TEMPLATE_IDS[form_number][notification_type]
      return unless template_id

      return if personalization['first_name'].blank?

      if at
        enqueue_email(at, template_id)
      else
        send_email_now(template_id)
      end
    end

    private

    def check_missing_keys(config)
      missing_keys = %i[form_data form_number confirmation_number date_submitted].select { |key| config[key].nil? }
      raise ArgumentError, "Missing keys: #{missing_keys.join(', ')}" if missing_keys.any?
    end

    def flipper?
      Flipper.enabled?(:"form#{form_number.gsub('vba_', '')}_confirmation_email")
    end

    def enqueue_email(at, template_id)
      # async job and we have a UserAccount
      if user
        VANotify::UserAccountJob.perform_at(
          at,
          user.uuid,
          template_id,
          personalization
        )
      # async job and we don't have a UserAccount but form data should include email
      else
        return if email_address.blank?

        VANotify::EmailJob.perform_at(
          at,
          email_address,
          template_id,
          personalization
        )
      end
    end

    def send_email_now(template_id)
      # sync job and we have a @current_user
      if user
        VANotify::EmailJob.perform_async(
          user.va_profile_email,
          template_id,
          personalization
        )
      # sync job and form data should include email
      else
        return if email_address.blank?

        VANotify::EmailJob.perform_async(
          email_address,
          template_id,
          personalization
        )
      end
    end

    def personalization
      out = {
        'first_name' => user&.first_name&.upcase || first_name[form_number]&.upcase,
        'date_submitted' => date_submitted,
        'confirmation_number' => confirmation_number,
        'lighthouse_updated_at' => lighthouse_updated_at
      }
      out.merge!(form21_0966_personalization) if form_number == 'vba_21_0966'
      out
    end

    def email_address
      simple_email_addresses.merge(email_address2110210)[form_number]
    end

    def simple_email_addresses
      {
        'vba_21_0845' => form_data['authorizer_email'],
        'vba_21p_0847' => form_data['preparer_email'],
        'vba_21_0966' => form_data['veteran_email'],
        'vba_21_0972' => form_data['preparer_email'],
        'vba_21_4142' => form_data.dig('veteran', 'email'),
        'vba_20_10206' => form_data['email_address'],
        'vba_40_0247' => form_data['applicant_email']
      }
    end

    def email_address2110210
      value = if form_data['claim_ownership'] == 'self' && form_data['claimant_type'] == 'veteran'
                form_data['veteran_email']
              elsif form_data['claim_ownership'] == 'self' && form_data['claimant_type'] == 'non-veteran'
                form_data['claimant_email']
              elsif form_data['claim_ownership'] == 'third-party'
                form_data['witness_email']
              end
      { 'vba_21_10210' => value }
    end

    def first_name
      simple_first_names.merge(first_name210845, first_name2110210, first_name2010207)
    end

    def simple_first_names
      {
        'vba_21p_0847' => form_data.dig('preparer_name', 'first'),
        'vba_21_0966' => form_data.dig('veteran_full_name', 'first'),
        'vba_21_0972' => form_data.dig('preparer_full_name', 'first'),
        'vba_21_4142' => form_data.dig('veteran', 'full_name', 'first'),
        'vba_20_10206' => form_data.dig('full_name', 'first'),
        'vba_40_0247' => form_data.dig('applicant_full_name', 'first')
      }
    end

    def first_name210845
      value = if form_data['authorizer_type'] == 'veteran'
                form_data.dig('veteran_full_name', 'first')
              elsif form_data['authorizer_type'] == 'nonVeteran'
                form_data.dig('authorizer_full_name', 'first')
              end
      { 'vba_21_0845' => value }
    end

    def first_name2110210
      value = if form_data['claim_ownership'] == 'self' && form_data['claimant_type'] == 'veteran'
                form_data.dig('veteran_full_name', 'first')
              elsif form_data['claim_ownership'] == 'self' && form_data['claimant_type'] == 'non-veteran'
                form_data.dig('claimant_full_name', 'first')
              elsif form_data['claim_ownership'] == 'third-party'
                form_data.dig('witness_full_name', 'first')
              end

      { 'vba_21_10210' => value }
    end

    def first_name2010207
      value = if form_data['preparer_type'] == 'veteran'
                form_data.dig('veteran_full_name', 'first')
              elsif form_data['preparer_type'] == 'non-veteran'
                form_data.dig('non_veteran_full_name', 'first')
              else
                form_data.dig('third_party_full_name', 'first')
              end
      { 'vba_20_10207' => value }
    end

    def form21_0966_personalization
      benefits = form_data['benefit_selection']
      intent_to_file_benefits = if benefits['compensation'] && benefits['pension']
                                  'Disability Compensation (VA Form 21-526EZ) and Pension (VA Form 21P-527EZ)'
                                elsif benefits['compensation']
                                  'Disability Compensation (VA Form 21-526EZ)'
                                elsif benefits['pension']
                                  'Pension (VA Form 21P-527EZ)'
                                elsif benefits['survivor']
                                  'Survivors Pension and/or Dependency and Indemnity Compensation (DIC)' \
                                    ' (VA Form 21P-534 or VA Form 21P-534EZ)'
                                end
      { 'intent_to_file_benefits' => intent_to_file_benefits }
    end
  end
end
