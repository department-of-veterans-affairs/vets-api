# frozen_string_literal: true

class SavedClaim::VeteranReadinessEmploymentClaim < SavedClaim
  FORM = '28-1900'

  def add_claimant_info(user)
    form_data = parsed_form

    vet_info = {
      'veteranInformation' => {
        'fullName' => {
          'first' => user.first_name,
          'middle' => user.middle_name,
          'last' => user.last_name,
          'suffix' => nil
        },
        'ssn' => user.ssn,
        'VAFileNumber' => veteran_va_file_number(user),
        'pid' => user.participant_id,
        'edipi' => user.edipi,
        'vet360ID' => user.vet360_id,
        'dob' => user.birth_date
      }
    }

    self.form = form_data.merge!(vet_info).to_json
  end

  def send_to_vre
    conn = Faraday.new(url: ENV['TEMP_VRE_CH31_SUBMISSION_DOMAIN'])

    conn.post do |req|
      req.url ENV['TEMP_VRE_CH31_SUBMISSION_ENDPOINT']
      req.headers['Authorization'] = "Bearer #{get_token}"
      req.headers['Content-Type'] = 'application/json'
      req.body = format_payload_for_vre
    end
  end

  private

  def veteran_va_file_number(user)
    service = BGS::PeopleService.new(user)
    response = service.find_person_by_participant_id

    response[:file_nbr]
  rescue
    nil
  end

  # rubocop:disable Metrics/MethodLength
  def format_payload_for_vre
    form_data = parsed_form

    vre_payload = {
      data: {
        educationLevel: form_data['years_of_education'],
        useEva: form_data['use_eva'],
        useTelecounseling: form_data['use_telecounseling'],
        meetingTime: form_data['appointment_time_preferences'].key(true),
        isMoving: form_data['is_moving'],
        mainPhone: form_data['main_phone'],
        cellPhone: form_data['cell_phone'],
        emailAddress: form_data['email'],
        veteranAddress: {
          isForeign: form_data['veteran_address']['country'] != 'USA',
          isMilitary: form_data['veteran_address']['is_military'],
          countryName: form_data['veteran_address']['country'],
          addressLine1: form_data['veteran_address']['street'],
          addressLine2: form_data['veteran_address']['street2'],
          addressLine3: form_data['veteran_address']['street3'],
          city: form_data['veteran_address']['city'],
          stateCode: form_data['veteran_address']['state'],
          zipCode: form_data['veteran_address']['postal_code']
        }
      }
    }

    vre_payload[:data].merge!({ veteranInformation: parsed_form['veteranInformation'] })
    vre_payload[:data].merge!(new_address) if parsed_form['new_address'].present?

    vre_payload.to_json
  end
  # rubocop:enable Metrics/MethodLength

  def new_address
    new_address = parsed_form['new_address']
    {
      "newAddress": {
        "isForeign": new_address['country'] != 'USA',
        "isMilitary": new_address['is_military'],
        "countryName": new_address['country'],
        "addressLine1": new_address['street'],
        "addressLine2": new_address['street2'],
        "addressLine3": new_address['street3'],
        "city": new_address['city'],
        "province": new_address['state'],
        "internationalPostalCode": new_address['postal_code']
      }
    }
  end

  def get_token
    conn = Faraday.new(
      "#{ENV['TEMP_VRE_AUTH_ENDPOINT']}?grant_type=client_credentials",
      headers: { 'Authorization' => "Basic #{ENV['TEMP_VRE_CREDENTIALS']}" }
    )

    request = conn.post

    JSON.parse(request.body)['access_token']
  end
end
