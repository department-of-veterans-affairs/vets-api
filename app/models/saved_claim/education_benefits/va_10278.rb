# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10278 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10278')

  def generate_benefits_intake_metadata
    personal_info = parsed_form['claimantPersonalInformation']
    ::BenefitsIntake::Metadata.generate(
      personal_info['fullName']['first'],
      personal_info['fullName']['last'],
      personal_info['vaFileNumber'] || personal_info['ssn'],
      parsed_form['claimantAddress']['postalCode'],
      self.class.to_s,
      '22-10278', # doc type
      'EDU' # busines line
    )
  end

  def send_email(email_type)
    EducationBenefitsClaims::NotificationEmail.new(id).deliver(email_type)
  end

  # the personalization params to send with VANotify
  def personalisation
    full_name = parsed_form['claimantPersonalInformation']['fullName']
    {
      first_name: full_name['first'],
      last_name: full_name['last']
    }
  end

  # the email address to send VANotify success/failure emails to
  def email
    parsed_form['claimantContactInformation']['emailAddress']
  end
end
