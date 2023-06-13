# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA1990e < SavedClaim::EducationBenefits
  add_form_and_validation('22-1990E')

  def after_submit(user)
    return unless Flipper.enabled?(:form1990e_confirmation_email)

    if Flipper.enabled?(:form1990e_auth_confirmation_email)
      # allow for phased rollout of authenticated users
    elsif user.present?
      # skip sending to authenticated users
      return
    end

    parsed_form_data ||= JSON.parse(form)
    email = parsed_form_data['email']
    return if email.blank?

    send_confirmation_email(email)
  end

  private

  def send_confirmation_email(email)
    VANotify::EmailJob.perform_async(
      email,
      Settings.vanotify.services.va_gov.template_id.form1990e_confirmation_email,
      {
        'first_name' => parsed_form.dig('relativeFullName', 'first')&.upcase.presence,
        'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
        'confirmation_number' => education_benefits_claim.confirmation_number,
        'regional_office_address' => regional_office_address
      }
    )
  end
end
