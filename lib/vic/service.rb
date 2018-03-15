# frozen_string_literal: true

module VIC
  class Service < Common::Client::Base
    configuration VIC::Configuration

    SALESFORCE_USERNAMES = {
      'prod' => 'vetsgov-devops@listserv.gsa.gov',
      'uat' => 'vetsgov-devops@listserv.gsa.gov.uat',
      'dev' => 'vetsgov-devops@listserv.gsa.gov.vicdev'
    }.freeze

    SALESFORCE_USERNAME = SALESFORCE_USERNAMES[Settings.salesforce.env]
    SALESFORCE_HOST = "https://#{Settings.salesforce.env == 'prod' ? 'login' : 'test'}.salesforce.com"
    SERVICE_BRANCHES = {
      'F' => 'Air Force',
      'A' => 'Army',
      'C' => 'Coast Guard',
      'M' => 'Marine Corps',
      'N' => 'Navy'
    }.freeze
    PROCESSING_WAIT = 10
    WHITELISTED_FORM_FIELDS = %w[
      service_branch
      email
      veteran_full_name
      veteran_address
      phone
    ].freeze

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
      ssn = converted_form.delete('veteran_social_security_number')
      converted_form.slice!(*WHITELISTED_FORM_FIELDS)

      veteran_address = converted_form['veteran_address']
      if veteran_address.present?
        veteran_address['street2'] = '' if veteran_address['street2'].blank?
        veteran_address['country'].tap do |country|
          next if country.blank?
          veteran_address['country'] = IsoCountryCodes.find(country).alpha2
        end
      end

      converted_form['profile_data'] = {
        'SSN' => ssn,
        'historical_ICN' => []
      }

      converted_form
    end

    def send_file(client, case_id, form_attachment, description)
      return if form_attachment.blank?

      file_body = form_attachment.get_file.read
      mime_type = MimeMagic.by_magic(file_body).type
      file_name = "#{description}.#{mime_type.split('/')[1]}"
      file_path = Common::FileHelpers.generate_temp_file(file_body)

      content_version_id = client.create!(
        'ContentVersion',
        Title: description, PathOnClient: file_name,
        VersionData: Restforce::UploadIO.new(
          file_path,
          mime_type
        )
      )

      client.create!(
        'ContentDocumentLink',
        ContentDocumentId: client.find('ContentVersion', content_version_id)['ContentDocumentId'],
        ShareType: 'V', LinkedEntityId: case_id
      )

      File.delete(file_path)
      form_attachment.destroy
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

      @attachment_records[:profile_photo] = VIC::ProfilePhotoAttachment.find_by(guid: form['photo']['confirmationCode'])

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

    def send_files(case_id, form)
      client = get_client
      attachment_records = get_attachment_records(form)
      attachment_records[:supporting].each_with_index do |form_attachment, i|
        send_file(client, case_id, form_attachment, "Discharge Documentation #{i}")
      end

      form_attachment = attachment_records[:profile_photo]
      send_file(client, case_id, form_attachment, 'Photo')
    end

    def add_loa3_overrides!(converted_form, user)
      full_name_normalized = user.full_name_normalized
      converted_form['veteran_full_name'] = full_name_normalized.stringify_keys.slice('first', 'middle', 'last')

      converted_form['profile_data']['SSN'] = user.ssn_normalized
    end

    def add_user_data!(converted_form, user)
      profile_data = converted_form['profile_data']
      va_profile = user.va_profile

      add_loa3_overrides!(converted_form, user) if user.loa3?

      if va_profile.present?
        profile_data['sec_ID'] = va_profile.sec_id
        profile_data['active_ICN'] = user.icn
        profile_data['historical_ICN'] = va_profile.historical_icns
      end

      if user.edipi.present?
        title38_status =
          begin
            user.veteran_status.title38_status
          rescue EMISRedis::VeteranStatus::RecordNotFound
            nil
          end

        converted_form['title38_status'] = title38_status
      end

      Common::HashHelpers.deep_compact(converted_form)
    end

    def wait_for_processed(form, start_time)
      return true if all_files_processed?(form)

      start_time_parsed = Time.zone.parse(start_time)
      raise Timeout::Error if (Time.zone.now - start_time_parsed) > PROCESSING_WAIT
      sleep(1)

      false
    end

    def get_client
      Restforce.new(
        oauth_token: get_oauth_token,
        instance_url: Configuration::SALESFORCE_INSTANCE_URL,
        api_version: '41.0'
      )
    end

    def submit(form, user)
      converted_form = convert_form(form)
      add_user_data!(converted_form, user) if user.present?

      client = get_client
      response_body = client.post('/services/apexrest/VICRequest', converted_form).body
      Raven.extra_context(submit_response_body: response_body)

      case_id = response_body['case_id']

      {
        case_id: case_id,
        case_number: response_body['case_number']
      }
    end
  end
end
