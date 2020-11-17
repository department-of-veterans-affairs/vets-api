# frozen_string_literal: true

require 'sentry_logging'

class SavedClaim::VeteranReadinessEmploymentClaim < SavedClaim
  include SentryLogging
  FORM = '28-1900'
  class VREError < StandardError; end

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
      'dob' => user.birth_date.strftime('%Y-%m-%d')
    }

    update(form: updated_form.to_json)
  end

  def send_to_vre
    conn = Faraday.new(url: Settings.vre.base_url)

    response = conn.post do |req|
      req.url Settings.vre.ch_31_endpoint
      req.headers['Authorization'] = "Bearer #{get_token}"
      req.headers['Content-Type'] = 'application/json'
      req.body = format_payload_for_vre
    end

    response_body = JSON.parse(response.body)
    return true if response_body['ErrorOccurred'] == false

    raise VREError
  rescue VREError => e
    log_exception_to_sentry(
      e,
      {
        error_message: response_body['ErrorMessage']
      },
      { team: 'vfs-ebenefits' }
    )
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

  def format_payload_for_vre
    form_data = parsed_form

    vre_payload = {
      data: {
        educationLevel: form_data['yearsOfEducation'],
        useEva: form_data['use_eva'],
        useTelecounseling: form_data['useTelecounseling'],
        meetingTime: form_data['appointmentTimePreferences'].key(true),
        isMoving: form_data['isMoving'],
        mainPhone: form_data['mainPhone'],
        cellPhone: form_data['cellPhone'],
        emailAddress: form_data['email']
      }
    }

    vre_payload[:data].merge!(veteran_address)
    vre_payload[:data].merge!({ veteranInformation: parsed_form['veteranInformation'] })
    vre_payload[:data].merge!(new_address) if parsed_form['newAddress'].present?
    vre_payload.to_json
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

  def get_token
    conn = Faraday.new(
      "#{Settings.vre.auth_endpoint}?grant_type=client_credentials",
      headers: { 'Authorization' => "Basic #{ENV['TEMP_VRE_CREDENTIALS']}" }
    )

    request = conn.post

    JSON.parse(request.body)['access_token']
  end
end
