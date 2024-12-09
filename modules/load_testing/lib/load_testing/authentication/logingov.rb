module LoadTesting
  module Authentication
    class Logingov
      def initialize(client_config)
        @client_config = client_config
      end

      def authorize_url(params)
        # Add any Logingov-specific parameters
        params.merge(
          acr_values: 'http://idmanagement.gov/ns/assurance/ial/1',
          prompt: 'select_account',
          scope: 'openid profile email'
        )
      end

      def token_url
        'https://idp.int.identitysandbox.gov/api/openid_connect/token'
      end

      def userinfo_url
        'https://idp.int.identitysandbox.gov/api/openid_connect/userinfo'
      end

      def client_assertion_type
        'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
      end
    end
  end
end 