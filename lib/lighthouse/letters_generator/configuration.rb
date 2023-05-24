# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_error'
require 'lighthouse/auth/client_credentials/jwt_generator'
require 'lighthouse/auth/client_credentials/service'

module Lighthouse
  module LettersGenerator
    class Configuration < Common::Client::Configuration::REST
      SETTINGS = Settings.lighthouse.letters_generator
      SCOPES = %w[letters.read].freeze

      def path_join(*paths)
        paths.reduce('') do |acc, p|
          trimmed_slash = p.gsub(%r{(^/+|/+$)}, '')
          acc + "#{trimmed_slash}/"
        end.chop!
      end

      def generator_url
        URI path_join(SETTINGS.url, SETTINGS.path)
      end

      def service_name
        'Lighthouse_LettersGenerator'
      end

      def connection
        @conn ||= Faraday.new(generator_url, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use      :breakers
          faraday.use      Faraday::Response::RaiseError

          faraday.request :json

          faraday.response :betamocks if use_mocks?
          faraday.response :json, { content_type: /\bjson/ }
          faraday.adapter Faraday.default_adapter
        end
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def use_mocks?
        SETTINGS.use_mocks || false
      end

      def get_access_token
        use_mocks? ? '' : token_service.get_token
      end

      def token_service
        token = SETTINGS.access_token
        url = URI path_join(SETTINGS.url, token.path)

        @token_service ||= Auth::ClientCredentials::Service.new(
          url, SCOPES, token.client_id, token.aud_claim_url, token.rsa_key
        )
      end
    end
  end
end
