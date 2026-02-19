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
end
