# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA5490 < SavedClaim::EducationBenefits
  add_form_and_validation('22-5490')

  def after_submit(_user)
    parsed_form_data ||= JSON.parse(form)
    email = parsed_form_data['email']
    return if email.blank?

    return unless Flipper.enabled?(:form5490_confirmation_email)

    send_confirmation_email(parsed_form_data, email)
  end

  private

  def send_confirmation_email(parsed_form_data, email)
    benefit = case parsed_form_data['benefit']
              when 'chapter35'
                'Survivors’ and Dependents’ Educational Assistance (DEA, Chapter 35)'
              when 'chapter33'
                'The Fry Scholarship (Chapter 33)'
              end

    VANotify::EmailJob.perform_async(
      email,
      Settings.vanotify.services.va_gov.template_id.form5490_confirmation_email,
      {
        'first_name' => parsed_form.dig('relativeFullName', 'first')&.upcase.presence,
        'benefit' => benefit,
        'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
        'confirmation_number' => education_benefits_claim.confirmation_number,
        'regional_office_address' => regional_office_address
      }
    )
  end
end
