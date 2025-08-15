# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA1995 < SavedClaim::EducationBenefits
  add_form_and_validation('22-1995')

  # Pulled from https://github.com/department-of-veterans-affairs/vets-website/src/applications/edu-benefits/utils/helpers.jsx#L100
  # & https://github.com/department-of-veterans-affairs/vets-website/blob/main/src/applications/edu-benefits/utils/labels.jsx
  BENEFIT_TITLE_FOR_1995 = {
    'chapter30' => 'Montgomery GI Bill (MGIB, Chapter 30)',
    'chapter33Post911' => 'Post-9/11 GI Bill (Chapter 33)',
    'chapter33FryScholarship' => 'Fry Scholarship (Chapter 33)',
    'chapter1606' => 'Montgomery GI Bill Selected Reserve (MGIB-SR, Chapter 1606)',
    'chapter32' => 'Post-Vietnam Era Veterans’ Educational Assistance Program (VEAP, chapter 32)',
    'transferOfEntitlement' => 'Transfer of Entitlement Program (TOE)'
  }.freeze

  def after_submit(user)
    return unless Flipper.enabled?(:form1995_confirmation_email)

    parsed_form_data = JSON.parse(form)
    # Use the user's profile email if available (logged in). Otherwise, use the form email.
    # The email's more likely to be if the profile email is available. Users
    # can fat finger their email on the form or it might not be their primary email.
    # If they're not logged in, we have to use the form email
    email = user&.email || parsed_form_data['email']
    return if email.blank?

    send_confirmation_email(parsed_form_data, email)
  end

  private

  def send_confirmation_email(parsed_form_data, email)
    benefit_claimed = BENEFIT_TITLE_FOR_1995[parsed_form_data['benefit']] || ''
    form_specific_params = { 'benefit' => benefit_claimed }

    # this method is in the parent class
    send_education_benefits_confirmation_email(email, parsed_form_data, form_specific_params)
  end

  def template_id
    Settings.vanotify.services.va_gov.template_id.form1995_confirmation_email
  end
end
