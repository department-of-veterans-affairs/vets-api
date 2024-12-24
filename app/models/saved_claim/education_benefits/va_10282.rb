# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10282 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10282')

  def after_submit(_user)
    return unless Flipper.enabled?(:form22_10282_confirmation_email)

    parsed_form_data = JSON.parse(form)
    email = parsed_form_data['email']
    return if email.blank?

    send_confirmation_email(parsed_form_data, email)
  end

  private

  def send_confirmation_email(parsed_form_data, email)
    VANotify::EmailJob.perform_async(
      email,
      Settings.vanotify.services.va_gov.template_id.form22_10282_confirmation_email,
      {
        'first_name' => parsed_form_data.dig('veteranFullName', 'first')&.upcase.presence,
        'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
        'confirmation_number' => education_benefits_claim.confirmation_number
      }
    )
  end
end
