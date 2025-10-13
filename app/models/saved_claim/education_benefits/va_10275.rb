# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10275 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10275')

  POE_EMAIL = 'tbd@example.com'

  def after_submit(_user)
    return unless Flipper.enabled?(:form22_10275_submission_email)

    email_template = Settings.vanotify.services.va_gov.template_id.form10275_submission_email
    email_params = {
      agreement_type: construct_agreement_type,
      institution_details: construct_institution_details,
      additional_locations: construct_additional_locations,
      points_of_contact: construct_points_of_contact,
      submission_information: construct_submission_information
    }

    VANotify::EmailJob.perform_async(
      Settings.form_10275.submission_email,
      email_template,
      email_params.merge(submission_id: id)
    )
  end

  private

  def construct_agreement_type
    case parsed_form['agreementType']
    when "newCommitment" then 'New commitment'
    when "withdrawal" then 'Withdrawl'
    else
      'Unknown'
    end
  end

  def construct_institution_details
    institution = parsed_form['mainInstitution']
    <<~DETAILS
    **Institution name:** #{institution['institutionName']}
    **Facility code:** #{institution['facilityCode']}
    **Institution address:**  
    #{format_address(institution['institutionAddress'])}
    DETAILS
  end

  def construct_additional_locations
    locations = (parsed_form['additionalInstitutions'] || []).map do |location|
      format_location(location)
    end.join("\n\n")
  end

  def construct_points_of_contact
    str = format_official(parsed_form['authorizedOfficial'], 'Authorizing official')

    if parsed_form['agreementType'] == 'newCommitment'
      poc = parsed_form['newCommitment']['principlesOfExcellencePointOfContact']
      sco = parsed_form['newCommitment']['schoolCertifyingOfficial']
      str += <<~OFF


        #{format_official(poc, 'Principles of Excellence point of contact', false)}

        #{format_official(sco, 'School certifying official', false)}
      OFF
    end

    str
  end

  def construct_submission_information
    <<~SUBMISSION
    **Date and time submitted:** #{parsed_form['dateSigned']}
    **Digitally signed by:** #{parsed_form['statementOfTruthSignature']}
    **Submission ID:** #{id}
    SUBMISSION
  end

  def format_location(location_hash)
    <<~LOCATION
      **#{location_hash['institutionName']}**  
      **Facility code:** #{location_hash['facilityCode']}
      **Address:**  
      #{format_address(location_hash['institutionAddress']).chomp}
      **Point of contact:** #{format_name(location_hash['pointOfContact']['fullName'])}
      **Email:**  #{location_hash['pointOfContact']['email']}
    LOCATION
  end

  def format_official(official_hash, header, include_title = true)
    str = "**#{header}:** #{format_name(official_hash['fullName'])}"
    str += "\n**Title:** #{official_hash['title']}" if include_title
    str += "\n**Phone number:** #{official_hash['usPhone'] || official_hash['internationalPhone']}"
    str += "\n**Email address:** #{official_hash['email']}"
    str
  end

  def format_address(address_hash)
    str = <<~ADDRESS
      #{address_hash['street']}
      #{address_hash['street2']}
      #{address_hash['city']}, #{address_hash['state']}, #{address_hash['postalCode']}
    ADDRESS

    str += "#{address_hash['country']}" unless ['US','USA'].include?(address_hash['country'])
    str
  end

  def format_name(name_hash)
    "#{name_hash['first']} #{name_hash['middle']} #{name_hash['last']}"
  end
end
