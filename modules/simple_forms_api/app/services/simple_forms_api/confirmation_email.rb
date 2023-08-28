# frozen_string_literal: true

module SimpleFormsApi
  class ConfirmationEmail
    attr_reader :form_number, :confirmation_number

    TEMPLATE_IDS = {
      'vba_21_4142' => Settings.vanotify.services.va_gov.template_id.form21_4142_confirmation_email
    }.freeze
    SUPPORTED_FORMS = TEMPLATE_IDS.keys

    def initialize(form_data:, form_number:, confirmation_number:)
      @form_data = form_data
      @form_number = form_number
      @confirmation_number = confirmation_number
    end

    def send
      return unless SUPPORTED_FORMS.include?(form_number)

      email = @form_data.dig('veteran', 'email')
      first_name = @form_data.dig('veteran', 'full_name', 'first')

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
  end
end
