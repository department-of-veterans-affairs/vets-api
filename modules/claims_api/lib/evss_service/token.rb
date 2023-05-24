# frozen_string_literal: true

module ClaimsApi
  module EVSSService
    class Token
      def initialize(request = nil)
        @request = request
      end

      def get_token
        body = {
          grant_type: 'client_credentials',
          client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
          client_assertion: assertion,
          scope: 'documents.read documents.write'
        }

        res = client.post(
          meta[:token_endpoint],
          URI.encode_www_form(body),
          { 'Content-Type': 'application/x-www-form-urlencoded' }
        )

        res.body[:access_token]
      end

      def meta
        base_name = if Settings.claims_api&.evss_container&.auth_base_name&.present?
                      Settings.claims_api.evss_container.auth_base_name
                    elsif @request&.host_with_port.nil?
                      'api.va.gov'
                    else
                      @request.host_with_port
                    end

        client.get("https://#{base_name}/oauth2/benefits-documents/system/v1/.well-known/openid-configuration").body
      end

      def assertion
        alg = 'HS256'
        client_secret = Settings.claims_api&.evss_container&.client_secret || ENV.fetch('LIGHTHOUSE_CCG_CLIENT_SECRET')
        client_id = Settings.claims_api&.evss_container&.client_id || ENV.fetch('LIGHTHOUSE_CCG_CLIENT_ID')

        raise StandardError, 'EVSS client_secret missing' if client_secret.blank?
        raise StandardError, 'EVSS client_id missing' if client_id.blank?

        payload = {
          aud: "#{meta[:issuer]}/v1/token",
          jti: SecureRandom.uuid,
          iss: client_id,
          sub: client_id,
          exp: 1.hour.from_now.to_i
        }
        JWT.encode(payload, client_secret, alg)
      end

      private

      def client
        Faraday.new do |f|
          f.request :json
          f.response :raise_error
          f.response :json, parser_options: { symbolize_names: true }
          f.adapter Faraday.default_adapter
        end
      end
    end
  end
end
