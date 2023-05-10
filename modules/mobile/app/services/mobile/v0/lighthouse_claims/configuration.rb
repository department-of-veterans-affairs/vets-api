# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'lighthouse/auth/client_credentials/jwt_generator'
require 'lighthouse/auth/client_credentials/service'
module Mobile
  module V0
    module LighthouseClaims
      class Configuration < BenefitsClaims::Configuration
        def token_service
          @token_service ||= begin
            url = "#{settings.host}/#{TOKEN_PATH}"
            benefits_token = settings.access_token
            mobile_token = Settings.mobile_lighthouse
            Auth::ClientCredentials::Service.new(
              url, API_SCOPES, mobile_token.client_id, benefits_token.aud_claim_url, mobile_token.rsa_key
            )
          end
        end
      end
    end
  end
end
