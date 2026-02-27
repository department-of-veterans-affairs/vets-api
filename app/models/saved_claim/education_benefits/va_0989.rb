# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA0989 < SavedClaim::EducationBenefits
  add_form_and_validation('22-0989')

  def requires_authenticated_user?
    true
  end

  def retention_period
    60.days
  end

  def generate_benefits_intake_metadata
    ::BenefitsIntake::Metadata.generate(
      parsed_form['applicantName']['first'],
      parsed_form['applicantName']['last'],
      parsed_form['vaFileNumber'] || parsed_form['ssn'],
      parsed_form['mailingAddress']['postalCode'],
      self.class.to_s,
      '22-0989', # doc type
      'EDU' # busines line
    )
  end

  # The `email_type` here needs to match one of the keys
  # in config/settings.yml under vanotify.services.<some_service>
  # By default, an `:error` email type is sent when the submit claim
  # job is exhausted (`monitor.track_submission_exhaustion`).
  # Otherwise, the email_types can pretty much be whatever you
  # want. It's common to have a `:received` type also for when
  # the submission reaches VBMS state in the benefits intake API
  def send_email(email_type)
    EducationBenefitsClaims::NotificationEmail.new(id).deliver(email_type)
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
