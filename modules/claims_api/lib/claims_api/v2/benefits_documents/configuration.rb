# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'lighthouse/auth/client_credentials/jwt_generator'
require 'lighthouse/auth/client_credentials/service'

module ClaimsApi
  module V2
    module BenefitsDocuments
      ##
      #
      class Configuration < ::Common::Client::Configuration::REST
        API_SCOPES = %w[documents.read documents.write].freeze
        TOKEN_PATH = 'oauth2/benefits-documents/system/v1/token'

        ##
        # @return [Config::Options] Settings for claims API benefits documents.
        #
        def settings
          Settings.claims_api.benefits_documents
        end

        ##
        # @return [String] Service name to use in breakers and metrics.
        #
        def service_name
          'LIGHTHOUSE_BENEFITS_DOCUMENTS'
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
          url = "#{settings.host}/#{TOKEN_PATH}"
          benefits_documents_client_id = settings.auth.ccg.client_id
          aud_claim_url = settings.auth.ccg.aud_claim_url
          benefits_documents_secret_key = settings.auth.ccg.secret_key

          @auth_token_service ||= Auth::ClientCredentials::Service.new(
            url, API_SCOPES, benefits_documents_client_id, aud_claim_url,
            benefits_documents_secret_key, 'claims_api:benefits-documents'
          )
        end
      end
    end
  end
end
