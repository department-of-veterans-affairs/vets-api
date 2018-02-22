# frozen_string_literal: true

module VIC
  class Service < Common::Client::Base
    configuration VIC::Configuration

    SALESFORCE_USERNAME = lambda do
      env = Settings.salesforce.env
      suffix = env
      suffix = "vic#{suffix}" unless env == 'uat'

      "vetsgov-devops@listserv.gsa.gov.#{suffix}"
    end.call
    # TODO: set correct prod value when we release to prod for salesforce_host
    SALESFORCE_HOST = 'https://test.salesforce.com'
    SERVICE_BRANCHES = {
      'F' => 'Air Force',
      'A' => 'Army',
      'C' => 'Coast Guard',
      'M' => 'Marine Corps',
      'N' => 'Navy'
    }.freeze
    PROCESSING_WAIT = 10

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
      body = request(:post, '', oauth_params).body
      Raven.extra_context(oauth_response_body: body)

      body['access_token']
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

    def send_file(client, case_id, file_body, description)
      mime_type = MimeMagic.by_magic(file_body).type
      file_name = "#{SecureRandom.hex}.#{mime_type.split('/')[1]}"
      file_path = Common::FileHelpers.generate_temp_file(file_body, file_name)

      success = client.create(
        'Attachment',
        ParentId: case_id,
        Description: description,
        Name: file_name,
        Body: Restforce::UploadIO.new(
          file_path,
          mime_type
        )
      )

      log_message_to_sentry('vic file upload failed', :error) unless success

      File.delete(file_path)
    end

    def get_attachment_records(form)
      return @attachment_records if @attachment_records.present?

      @attachment_records = {
        supporting: []
      }

      if form['dd214'].present?
        form['dd214'].each do |file|
          attachment = VIC::SupportingDocumentationAttachment.find_by(guid: file['confirmationCode'])
          @attachment_records[:supporting] << attachment
        end
      end

      form['photo'].tap do |file|
        @attachment_records[:profile_photo] = VIC::ProfilePhotoAttachment.find_by(guid: file['confirmationCode'])
      end

      @attachment_records
    end

    def all_files_processed?(form)
      attachment_records = get_attachment_records(form)

      attachment_records[:supporting].each do |form_attachment|
        return false unless form_attachment.get_file.exists?
      end

      return false unless attachment_records[:profile_photo].get_file.exists?

      true
    end

    def send_files(client, case_id, form)
      attachment_records = get_attachment_records(form)
      attachment_records[:supporting].each do |form_attachment|
        file_body = form_attachment.get_file.read
        send_file(client, case_id, file_body, 'Supporting Documentation')
      end

      file_body = attachment_records[:profile_photo].get_file.read
      send_file(client, case_id, file_body, 'Profile Photo')
    end

    def add_user_data!(converted_form, user)
      profile_data = converted_form['profile_data']
      va_profile = user.va_profile
      profile_data['sec_ID'] = va_profile.sec_id
      profile_data['active_ICN'] = user.icn

      if user.edipi.present?
        title38_status = user.veteran_status.title38_status
        converted_form['title38_status'] = title38_status
      end
      # TODO: historical icn
    end

    def wait_for_processed(form)
      start = Time.zone.now

      loop do
        return if all_files_processed?(form)

        raise Timeout::Error if (Time.zone.now - start) > PROCESSING_WAIT
        sleep(1)
      end
    end

    def submit(form, user)
      wait_for_processed(form)

      converted_form = convert_form(form)
      add_user_data!(converted_form, user) if user.present?

      client = Restforce.new(
        oauth_token: get_oauth_token,
        instance_url: Configuration::SALESFORCE_INSTANCE_URL,
        api_version: '41.0'
      )
      response_body = client.post('/services/apexrest/VICRequest', converted_form).body
      Raven.extra_context(submit_response_body: response_body)

      case_id = response_body['case_id']

      send_files(client, case_id, form)

      {
        case_id: case_id,
        case_number: response_body['case_number']
      }
    end
  end
end
