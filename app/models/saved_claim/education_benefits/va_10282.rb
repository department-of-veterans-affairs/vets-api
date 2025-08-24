# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10282 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10282')

  def after_submit(user)
    return unless Flipper.enabled?(:form22_10282_confirmation_email)

    parsed_form_data = JSON.parse(form)
    email = user&.email || parsed_form_data['email']
    return if email.blank?

    # The form 22-10282 confirmation email doesn't include a regional office address
    # so set regional_office to false
    send_education_benefits_confirmation_email(email, parsed_form_data, {}, false)
  end
end
