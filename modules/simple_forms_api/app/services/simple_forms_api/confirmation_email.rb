# frozen_string_literal: true

module SimpleFormsApi
  class ConfirmationEmail
    attr_reader :form_number, :confirmation_number, :user

    TEMPLATE_IDS = {
      'vba_21_0845' => Settings.vanotify.services.va_gov.template_id.form21_0845_confirmation_email,
      'vba_21p_0847' => Settings.vanotify.services.va_gov.template_id.form21p_0847_confirmation_email,
      'vba_21_0966' => Settings.vanotify.services.va_gov.template_id.form21_0966_confirmation_email,
      'vba_21_0972' => Settings.vanotify.services.va_gov.template_id.form21_0972_confirmation_email,
      'vba_21_4142' => Settings.vanotify.services.va_gov.template_id.form21_4142_confirmation_email,
      'vba_21_10210' => Settings.vanotify.services.va_gov.template_id.form21_10210_confirmation_email,
      'vba_20_10206' => Settings.vanotify.services.va_gov.template_id.form20_10206_confirmation_email,
      'vba_40_0247' => Settings.vanotify.services.va_gov.template_id.form40_0247_confirmation_email
    }.freeze
    SUPPORTED_FORMS = TEMPLATE_IDS.keys

    def initialize(form_data:, form_number:, confirmation_number:, user: nil)
      @form_data = form_data
      @form_number = form_number
      @confirmation_number = confirmation_number
      @user = user
    end

    def send
      return unless SUPPORTED_FORMS.include?(form_number)

      data = form_specific_data

      return if data[:email].blank? || data[:personalization]['first_name'].blank?

      template_id = TEMPLATE_IDS[form_number]

      VANotify::EmailJob.perform_async(
        data[:email],
        template_id,
        data[:personalization]
      )
    end

    private

    # rubocop:disable Metrics/MethodLength
    # email and personalization hash
    def form_specific_data
      case @form_number
      when 'vba_21_0845'
        return unless Flipper.enabled?(:form21_0845_confirmation_email)

        email, first_name = form21_0845_contact_info

        { email:, personalization: default_personalization(first_name) }
      when 'vba_21p_0847'
        return unless Flipper.enabled?(:form21p_0847_confirmation_email)

        {
          email: @form_data['preparer_email'],
          personalization: default_personalization(@form_data.dig('preparer_name', 'first'))
        }
      when 'vba_21_0966'
        return unless Flipper.enabled?(:form21_0966_confirmation_email)

        {
          email: @user.va_profile_email,
          personalization: default_personalization(@user.first_name)
            .merge(form21_0966_personalization)
        }
      when 'vba_21_0972'
        return unless Flipper.enabled?(:form21_0972_confirmation_email)

        {
          email: @form_data['preparer_email'],
          personalization: default_personalization(@form_data.dig('preparer_full_name', 'first'))
        }
      when 'vba_21_4142'
        return unless Flipper.enabled?(:form21_4142_confirmation_email)

        {
          email: @form_data.dig('veteran', 'email'),
          personalization: default_personalization(@form_data.dig('veteran', 'full_name', 'first'))
        }
      when 'vba_21_10210'
        return unless Flipper.enabled?(:form21_10210_confirmation_email)

        email, first_name = form21_10210_contact_info

        { email:, personalization: default_personalization(first_name) }
      when 'vba_20_10206'
        return unless Flipper.enabled?(:form20_10206_confirmation_email)

        email, first_name = form20_10206_contact_info

        { email:, personalization: default_personalization(first_name) }
      when 'vba_40_0247'
        return unless Flipper.enabled?(:form40_0247_confirmation_email)

        {
          email: @form_data['applicant_email'],
          personalization: default_personalization(@form_data.dig('applicant_full_name', 'first'))
        }
      else
        {}
      end
    end
    # rubocop:enable Metrics/MethodLength

    # personalization hash shared by all simple form confirmation emails
    def default_personalization(first_name)
      {
        'first_name' => first_name&.upcase,
        'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
        'confirmation_number' => confirmation_number
      }
    end

    # email and first name for form 20-10206
    def form20_10206_contact_info
      # email address not required and omitted
      if @form_data['email_address'].blank? && @user
        [@user.va_profile_email, @form_data.dig('full_name', 'first')]

      # email address not required and optionally entered
      else
        [@form_data['email_address'], @form_data.dig('full_name', 'first')]
      end
    end

    # email and first name for form 21-0845
    def form21_0845_contact_info
      # (vet && signed in)
      if @form_data['authorizer_type'] == 'veteran' && @user
        [@user.va_profile_email, @form_data.dig('veteran_full_name', 'first')]

      # (non-vet && signed in) || (non-vet && anon)
      elsif @form_data['authorizer_type'] == 'nonVeteran'
        [@form_data['authorizer_email'], @form_data.dig('authorizer_full_name', 'first')]

      # (vet && anon)
      else
        [nil, nil]
      end
    end

    # email and first name for form 21-10210
    def form21_10210_contact_info
      # user's own claim
      # user is a veteran
      if @form_data['claim_ownership'] == 'self' && @form_data['claimant_type'] == 'veteran'
        [@form_data['veteran_email'], @form_data.dig('veteran_full_name', 'first')]

      # user's own claim
      # user is not a veteran
      elsif @form_data['claim_ownership'] == 'self' && @form_data['claimant_type'] == 'non-veteran'
        [@form_data['claimant_email'], @form_data.dig('claimant_full_name', 'first')]

      # someone else's claim
      # claimant (aka someone else) is a veteran
      # or
      # claimant (aka someone else) is not a veteran
      elsif @form_data['claim_ownership'] == 'third-party'
        [@form_data['witness_email'], @form_data.dig('witness_full_name', 'first')]

      else
        [nil, nil]
      end
    end

    def form21_0966_personalization
      benefits = @form_data['benefit_selection']
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
