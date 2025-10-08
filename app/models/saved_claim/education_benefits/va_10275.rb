# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10275 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10275')

  POE_EMAIL = 'tbd@example.com'

  def after_submit(_user)
    return unless Flipper.enabled?(:form22_10275_submission_email)

    email_template = Settings.vanotify.services.va_gov.template_id.form10275_submission_email
    email_params = construct_email_parts

    VANotify::EmailJob.perform_async(
      Settings.form_10275.submission_email,
      email_template,
      email_params.merge(submission_id: id)
    )
  end

  private

  def construct_email_parts
    address_hash = parsed_form.dig('mainInstitution', 'institutionAddress') || {}

    header = <<-HEADER
      Agreement Type: #{parsed_form['agreementType']}
      Institution Name: #{parsed_form.dig('mainInstitution', 'institutionName')}
      Institution Facility Code: #{parsed_form.dig('mainInstitution', 'facilityCode')}
      Institution Address: #{format_address(address_hash)}
    HEADER

    locations = (parsed_form['additionalInstitutions'] || []).map do |location|
      format_location(location)
    end.join("\n\n")

    officials = construct_officials

    signature = <<-SIGNATURES
      Signed: #{parsed_form['statementOfTruthSignature']} (#{parsed_form['dateSigned']})
    SIGNATURES

    { header:, locations:, officials:, signature: }
  end

  def construct_officials
    if parsed_form['agreementType'] == 'newCommitment'
      poc = parsed_form['newCommitment']['principlesOfExcellencePointOfContact']
      sco = parsed_form['newCommitment']['schoolCertifyingOfficial']
      <<-OFFICIALS
        Principles of Excellence Point of Contact
          #{format_name(poc)} #{poc['title']}
          #{poc['usPhone'] || pos['internationalPhone']}
          #{poc['email']}

        School Certifying Official
          #{format_name(sco)} #{sco['title']}
          #{sco['usPhone'] || pos['internationalPhone']}
          #{sco['email']}
      OFFICIALS
    else
      ''
    end
  end

  def format_location(location_hash)
    <<-LOCATION
      Name: #{location_hash['institutionName']}
      Facility Code: #{location_hash['facilityCode']}
      Address: #{format_address(location_hash['institutionAddress'])}
      POC: #{format_name(location_hash['pointOfContact']['fullName'])} #{location_hash['pointOfContact']['email']}
    LOCATION
  end

  def format_address(address_hash)
    <<-ADDRESS
      #{address_hash['street']}
      #{address_hash['street2']}
      #{address_hash['city']}, #{address_hash['state']}, #{address_hash['postalCode']}
      #{address_hash['country']}
    ADDRESS
  end

  def format_name(name_hash)
    "#{name_hash['first']} #{name_hash['middle']} #{name_hash['last']}"
  end
end
