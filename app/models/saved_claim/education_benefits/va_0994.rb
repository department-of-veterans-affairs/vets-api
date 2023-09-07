# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA0994 < SavedClaim::EducationBenefits
  add_form_and_validation('22-0994')

  def after_submit(_user)
    return unless Flipper.enabled?(:form0994_confirmation_email)

    parsed_form_data ||= JSON.parse(form)
    email = parsed_form_data['emailAddress']

    return if email.blank?

    send_confirmation_email(parsed_form_data, email)
  end

  private

  def send_confirmation_email(parsed_form_data, email)
    email_template = if parsed_form_data['appliedForVaEducationBenefits']
                       Settings.vanotify.services.va_gov.template_id.form0994_confirmation_email
                     else
                       Settings.vanotify.services.va_gov.template_id.form0994_extra_action_confirmation_email
                     end

    VANotify::EmailJob.perform_async(
      email,
      email_template,
      {
        'first_name' => parsed_form_data.dig('applicantFullName', 'first')&.upcase.presence,
        'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
        'confirmation_number' => education_benefits_claim.confirmation_number,
        'regional_office_address' => regional_office_address
      }
    )
  end
end
