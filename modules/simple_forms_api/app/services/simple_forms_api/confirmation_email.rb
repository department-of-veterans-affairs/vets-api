# frozen_string_literal: true

module SimpleFormsApi
  class ConfirmationEmail
    attr_reader :form_number, :confirmation_number, :user

    TEMPLATE_IDS = {
      'vba_21_0845' => Settings.vanotify.services.va_gov.template_id.form21_0845_confirmation_email,
      'vba_21p_0847' => Settings.vanotify.services.va_gov.template_id.form21p_0847_confirmation_email,
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

      email, first_name = form_specific_data

      return if email.blank? || first_name.blank?

      template_id = TEMPLATE_IDS[form_number]

      VANotify::EmailJob.perform_async(
        email,
        template_id,
        {
          'first_name' => first_name.upcase,
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'confirmation_number' => confirmation_number
        }
      )
    end

    private

    # rubocop:disable Metrics/MethodLength
    def form_specific_data
      email, first_name = case @form_number
                          when 'vba_21_0845'
                            return unless Flipper.enabled?(:form21_0845_confirmation_email)

                            form21_0845_contact_info(@form_data)
                          when 'vba_21p_0847'
                            return unless Flipper.enabled?(:form21p_0847_confirmation_email)

                            [@form_data['preparer_email'], @form_data.dig('preparer_name', 'first')]
                          when 'vba_21_0972'
                            return unless Flipper.enabled?(:form21_0972_confirmation_email)

                            [@form_data['preparer_email'], @form_data.dig('preparer_full_name', 'first')]
                          when 'vba_21_4142'
                            return unless Flipper.enabled?(:form21_4142_confirmation_email)

                            [@form_data.dig('veteran', 'email'), @form_data.dig('veteran', 'full_name', 'first')]
                          when 'vba_21_10210'
                            return unless Flipper.enabled?(:form21_10210_confirmation_email)

                            form21_10210_contact_info(@form_data)
                          when 'vba_20_10206'
                            return unless Flipper.enabled?(:form20_10206_confirmation_email)

                            form20_10206_contact_info(@form_data)
                          when 'vba_40_0247'
                            return unless Flipper.enabled?(:form40_0247_confirmation_email)

                            [@form_data['applicant_email'], @form_data.dig('applicant_full_name', 'first')]
                          else
                            [nil, nil]
                          end

      [email, first_name]
    end
    # rubocop:enable Metrics/MethodLength

    def form20_10206_contact_info(form_data)
      # email address not required and omitted
      if form_data['email_address'].blank? && @user
        [@user.va_profile_email, form_data.dig('full_name', 'first')]

      # email address not required and optionally entered
      else
        [form_data['email_address'], form_data.dig('full_name', 'first')]
      end
    end

    def form21_0845_contact_info(form_data)
      # (vet && signed in)
      if form_data['authorizer_type'] == 'veteran' && @user
        [@user.va_profile_email, form_data.dig('veteran_full_name', 'first')]

      # (non-vet && signed in) || (non-vet && anon)
      elsif form_data['authorizer_type'] == 'nonVeteran'
        [form_data['authorizer_email'], form_data.dig('authorizer_full_name', 'first')]

      # (vet && anon)
      else
        [nil, nil]
      end
    end

    def form21_10210_contact_info(form_data)
      # user's own claim
      # user is a veteran
      if form_data['claim_ownership'] == 'self' && form_data['claimant_type'] == 'veteran'
        [form_data['veteran_email'], form_data.dig('veteran_full_name', 'first')]

      # user's own claim
      # user is not a veteran
      elsif form_data['claim_ownership'] == 'self' && form_data['claimant_type'] == 'non-veteran'
        [form_data['claimant_email'], form_data.dig('claimant_full_name', 'first')]

      # someone else's claim
      # claimant (aka someone else) is a veteran
      # or
      # claimant (aka someone else) is not a veteran
      elsif form_data['claim_ownership'] == 'third-party'
        [form_data['witness_email'], form_data.dig('witness_full_name', 'first')]

      else
        [nil, nil]
      end
    end
  end
end
