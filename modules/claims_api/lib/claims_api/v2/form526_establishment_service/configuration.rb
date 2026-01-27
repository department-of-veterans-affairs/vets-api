# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'lighthouse/auth/client_credentials/jwt_generator'
require 'lighthouse/auth/client_credentials/service'

module ClaimsApi
  module V2
    module Form526EstablishmentService
      class Configuration < ::Common::Client::Configuration::REST
        API_SCOPES = %w[system/Form526.read system/Form526.write].freeze
        TOKEN_PATH = 'oauth2/benefits-documents/system/v1/token' # FES uses same auth server as BD

        ##
        # @return [Config::Options] Settings for claims API Form526 Establishment Service.
        #
        def settings
          Settings.claims_api.fes
        end

        ##
        # @return [String] Service name to use in breakers and metrics.
        #
        def service_name
          'LIGHTHOUSE_FORM526_ESTABLISHMENT_SERVICE'
        end

        def get_access_token
          token_service.get_token if get_access_token?
        end

        private

        ##
        # @return [Boolean] Should the service use mock data in lower environments.
        #
        def use_mocks?
          settings.use_mocks || false
        end

        def get_access_token?
          !use_mocks? || Settings.betamocks.recording
        end

        ##
        # @return [Auth::ClientCredentials::Service] Service used to generate access tokens.
        #
        def token_service
          url = "#{settings.token_host}/#{TOKEN_PATH}"
          fes_client_id = settings.auth.ccg.client_id
          aud_claim_url = settings.auth.ccg.aud_claim_url
          fes_secret_key = settings.auth.ccg.secret_key

          @auth_token_service ||= Auth::ClientCredentials::Service.new(
            url, API_SCOPES, fes_client_id, aud_claim_url,
            fes_secret_key, 'claims_api:form526-establishment-service'
          )
        end
      end
    end
  end
end
