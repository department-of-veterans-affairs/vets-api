# frozen_string_literal: true

module Salesforce
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    SALESFORCE_HOST = "https://#{Settings.salesforce.env == 'prod' ? 'login' : 'test'}.salesforce.com".freeze

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
        iss: self.class::CONSUMER_KEY,
        sub: self.class::SALESFORCE_USERNAME,
        aud: SALESFORCE_HOST,
        exp: Time.now.utc.to_i
      }
    end

    def private_key
      OpenSSL::PKey::RSA.new(File.read(self.class::SIGNING_KEY_PATH))
    end

    def get_oauth_token
      body = with_monitoring { request(:post, '', oauth_params).body }
      Raven.extra_context(oauth_response_body: body)

      body['access_token']
    end

    def get_client
      Restforce.new(
        oauth_token: get_oauth_token,
        instance_url: self.class.module_parent::Configuration::SALESFORCE_INSTANCE_URL,
        api_version: '41.0'
      )
    end
  end
end
