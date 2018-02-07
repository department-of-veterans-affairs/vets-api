# frozen_string_literal: true

module VIC
  class Service < Common::Client::Base
    configuration VIC::Configuration

    SALESFORCE_USERNAME = 'vetsgov-devops@listserv.gsa.gov.vicdev'
    SALESFORCE_HOST = 'https://test.salesforce.com'
    SERVICE_BRANCHES = {
      'F' => 'Air Force',
      'A' => 'Army',
      'C' => 'Coast Guard',
      'M' => 'Marine Corps',
      'N' => 'Navy',
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
      converted_form.delete('dd214')
      converted_form.delete('veteran_date_of_birth')

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
        'SSN' => ssn
      }

      converted_form.delete('gender')
      converted_form
    end

    def add_user_data!(converted_form, user)
      profile_data = converted_form['profile_data']
      va_profile = user.va_profile
      profile_data['sec_ID'] = va_profile.sec_id
      profile_data['active_ICN'] = user.icn
      # TODO historical icn
    end

    def submit(form, user)
      converted_form = convert_form(form)
      add_user_data!(converted_form, user) if user.present?

      binding.pry; fail
      client = Restforce.new(
        oauth_token: get_oauth_token,
        instance_url: Configuration::SALESFORCE_INSTANCE_URL,
        api_version: '41.0'
      )
      binding.pry; fail

      {
        confirmation_number: SecureRandom.uuid
      }
    end
  end
end
