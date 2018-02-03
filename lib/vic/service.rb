# frozen_string_literal: true

module VIC
  class Service < Common::Client::Base
    configuration VIC::Configuration

    SALESFORCE_USERNAME = 'vetsgov-devops@listserv.gsa.gov.vicdev'
    SALESFORCE_HOST = 'https://test.salesforce.com'

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
      request(:post, '', oauth_params)
    end

    def submit(_form)
      {
        confirmation_number: SecureRandom.uuid
      }
    end
  end
end
