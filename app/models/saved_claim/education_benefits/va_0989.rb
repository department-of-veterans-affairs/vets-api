# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA0989 < SavedClaim::EducationBenefits
  add_form_and_validation('22-0989')

  def requires_authenticated_user?
    true
  end

  def retention_period
    60.days
  end

  # the personalization params to send with VANotify
  def personalisation
    {
      first_name: parsed_form['applicantName']['first'],
      last_name: parsed_form['applicantName']['last']
    }
  end

  # the email address to send VANotify success/failure emails to
  def email
    parsed_form['emailAddress']
  end
end
