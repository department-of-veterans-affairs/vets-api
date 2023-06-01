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

  def after_submit(_user)
    return unless Flipper.enabled?(:form1995_confirmation_email)

    parsed_form_data ||= JSON.parse(form)
    email = parsed_form_data['email']
    return if email.blank?

    send_confirmation_email(parsed_form_data, email)
  end

  private

  def send_confirmation_email(parsed_form_data, email)
    VANotify::EmailJob.perform_async(
      email,
      Settings.vanotify.services.va_gov.template_id.form1995_confirmation_email,
      {
        'first_name' => parsed_form.dig('veteranFullName', 'first')&.upcase.presence,
        'benefit' => benefit_claimed(parsed_form_data),
        'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
        'confirmation_number' => education_benefits_claim.confirmation_number,
        'regional_office_address' => regional_office_address
      }
    )
  end

  def benefit_claimed(parsed_form_data)
    benefit ||= parsed_form_data['benefit']
    BENEFIT_TITLE_FOR_1995[benefit]
  end
end
