# frozen_string_literal: true

module VIC
  class Service < Common::Client::Base
    configuration VIC::Configuration

    SALESFORCE_USERNAME = "vetsgov-devops@listserv.gsa.gov.vic#{Settings.salesforce.env}"
    # TODO: set correct prod value when we release to prod for salesforce_host
    SALESFORCE_HOST = 'https://test.salesforce.com'
    SERVICE_BRANCHES = {
      'F' => 'Air Force',
      'A' => 'Army',
      'C' => 'Coast Guard',
      'M' => 'Marine Corps',
      'N' => 'Navy'
    }.freeze
    TITLE_38_PICKLIST = {
      'V1' => 'V1 - Title 38 Veteran',
      'V2' => 'V2 - VA Beneficiary',
      'V3' => 'V3 - Military Person, Not Title 38 Veteran, Not DoD Affiliate',
      'V4' => 'V4 - Military or Beneficiary Status Unknown',
      'V5' => 'V5 - EDI PI Not Known in VADIR (used in service calls only; not a stored value)',
      'V6' => 'V6 - Military Person, Not Title 38 Veteran, DoD Affiliate (indicates current military)',
      'V7' => 'V7 - Military Person, Not Title 38 Veteran, Not DoD Affiliate, “Bad Paper” Discharge(s)'
    }.freeze

    def oauth_params
      {
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt_bearer_token
      }
    end

    def jwt_bearer_token
      JWT.encode(claim_set, private_key, 'RS256')
    end

    def claim_set
      {
        iss: Settings.salesforce.consumer_key,
        sub: SALESFORCE_USERNAME,
        aud: SALESFORCE_HOST,
        exp: Time.now.utc.to_i.to_s
      }
    end

    def private_key
      OpenSSL::PKey::RSA.new(File.read(Settings.salesforce.signing_key_path))
    end

    def get_oauth_token
      request(:post, '', oauth_params).body['access_token']
    end

    def convert_form(form)
      converted_form = form.deep_transform_keys { |key| key.to_s.underscore }
      converted_form['service_branch'] = SERVICE_BRANCHES[converted_form['service_branch']]
      %w[dd214 photo privacy_agreement_accepted veteran_date_of_birth gender].each do |attr|
        converted_form.delete(attr)
      end

      veteran_address = converted_form['veteran_address']
      if veteran_address.present?
        veteran_address['street2'] = '' if veteran_address['street2'].blank?
        veteran_address['country'].tap do |country|
          next if country.blank?
          veteran_address['country'] = IsoCountryCodes.find(country).alpha2
        end
      end

      ssn = converted_form.delete('veteran_social_security_number')
      converted_form['profile_data'] = {
        'SSN' => ssn,
        'historical_ICN' => []
      }

      converted_form
    end

    def generate_temp_file(file_body, file_name)
      file_path = "tmp/#{file_name}"

      File.open(file_path, 'wb') do |file|
        file.write(file_body)
      end

      file_path
    end

    def send_file(client, case_id, file_body, description)
      mime_type = MimeMagic.by_magic(file_body).type
      file_name = "#{SecureRandom.hex}.#{mime_type.split('/')[1]}"
      file_path = generate_temp_file(file_body, file_name)

      client.create(
        'Attachment',
        ParentId: case_id,
        Description: description,
        Name: file_name,
        Body: Restforce::UploadIO.new(
          file_path,
          mime_type
        )
      )

      File.delete(file_path)
    end

    def send_files(client, case_id, form)
      if form['dd214'].present?
        form['dd214'].each do |file|
          file_body = VIC::SupportingDocumentationAttachment.find_by(guid: file['confirmationCode']).get_file.read
          send_file(client, case_id, file_body, 'Supporting Documentation')
        end
      end

      form['photo'].tap do |file|
        file_body = VIC::ProfilePhotoAttachment.find_by(guid: file['confirmationCode']).get_file.read
        send_file(client, case_id, file_body, 'Profile Photo')
      end
    end

    def add_user_data!(converted_form, user)
      profile_data = converted_form['profile_data']
      va_profile = user.va_profile
      profile_data['sec_ID'] = va_profile.sec_id
      profile_data['active_ICN'] = user.icn

      if user.edipi.present?
        title38_status = user.veteran_status.title38_status
        converted_form['title38_status'] = TITLE_38_PICKLIST[title38_status]
      end
      # TODO: historical icn
    end

    def submit(form, user)
      converted_form = convert_form(form)
      add_user_data!(converted_form, user) if user.present?

      client = Restforce.new(
        oauth_token: get_oauth_token,
        instance_url: Configuration::SALESFORCE_INSTANCE_URL,
        api_version: '41.0'
      )
      response = client.post('/services/apexrest/VICRequest', converted_form)

      case_id = response.body['case_id']

      send_files(client, case_id, form)

      # TODO: figure out what to do when an upload fails

      { case_id: case_id }
    end
  end
end
