# frozen_string_literal: true

require 'sentry_logging'

class SavedClaim::VeteranReadinessEmploymentClaim < SavedClaim
  include SentryLogging
  FORM = '28-1900'

  def add_claimant_info(user)
    return if form.blank?

    updated_form = parsed_form

    updated_form['veteranInformation'] = {
      'fullName' => {
        'first' => user.first_name,
        'middle' => user.middle_name || '',
        'last' => user.last_name
      },
      'ssn' => user.ssn,
      'VAFileNumber' => veteran_va_file_number(user),
      'pid' => user.participant_id,
      'edipi' => user.edipi,
      'vet360ID' => user.vet360_id,
      'dob' => parsed_date(user.birth_date)
    }

    update(form: updated_form.to_json)
  end

  def send_to_vre(user)
    service = VRE::Ch31Form(user: user, claim: self)

    service.submit
  end

  # SavedClaims require regional_office to be defined
  def regional_office
    []
  end

  private

  def veteran_va_file_number(user)
    service = BGS::PeopleService.new(user)
    response = service.find_person_by_participant_id
    file_number = response[:file_nbr]
    file_number.presence
  rescue
    nil
  end

  def new_address
    new_address = parsed_form['newAddress']
    {
      "newAddress": {
        "isForeign": new_address['country'] != 'USA',
        "isMilitary": new_address['isMilitary'],
        "countryName": new_address['country'],
        "addressLine1": new_address['street'],
        "addressLine2": new_address['street2'],
        "addressLine3": new_address['street3'],
        "city": new_address['city'],
        "province": new_address['state'],
        "internationalPostalCode": new_address['postalCode']
      }
    }
  end

  def veteran_address
    form_data = parsed_form

    {
      veteranAddress: {
        isForeign: form_data['veteranAddress']['country'] != 'USA',
        isMilitary: form_data['veteranAddress']['isMilitary'] || false,
        countryName: form_data['veteranAddress']['country'],
        addressLine1: form_data['veteranAddress']['street'],
        addressLine2: form_data['veteranAddress']['street2'],
        addressLine3: form_data['veteranAddress']['street3'],
        city: form_data['veteranAddress']['city'],
        stateCode: form_data['veteranAddress']['state'],
        zipCode: form_data['veteranAddress']['postalCode']
      }
    }
  end

  def parsed_date(date)
    date.strftime('%Y-%m-%d')
  rescue
    date
  end
end
