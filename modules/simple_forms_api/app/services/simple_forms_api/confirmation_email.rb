# frozen_string_literal: true

module SimpleFormsApi
  class ConfirmationEmail
    attr_reader :form_number, :confirmation_number

    TEMPLATE_IDS = {
      'vba_21_4142' => Settings.vanotify.services.va_gov.template_id.form21_4142_confirmation_email,
      'vba_21_10210' => Settings.vanotify.services.va_gov.template_id.form21_10210_confirmation_email
    }.freeze
    SUPPORTED_FORMS = TEMPLATE_IDS.keys

    def initialize(form_data:, form_number:, confirmation_number:)
      @form_data = form_data
      @form_number = form_number
      @confirmation_number = confirmation_number
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

    def form_specific_data
      email, first_name = case @form_number
                          when 'vba_21_4142'
                            return unless Flipper.enabled?(:form21_4142_confirmation_email)

                            [@form_data.dig('veteran', 'email'), @form_data.dig('veteran', 'full_name', 'first')]
                          when 'vba_21_10210'
                            return unless Flipper.enabled?(:form21_10210_confirmation_email)

                            form21_10210_contact_info(@form_data)
                          else
                            [nil, nil]
                          end

      [email, first_name]
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
