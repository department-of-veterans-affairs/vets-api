# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'lighthouse/auth/client_credentials/service'

module Lighthouse
  module HealthcareCostAndCoverage
    class Configuration < Common::Client::Configuration::REST
      self.read_timeout = Settings.lighthouse.healthcare_cost_and_coverage.timeout || 30

      API_PATH   = 'services/health-care-costs-coverage/v0'
      TOKEN_PATH = 'oauth2/health-care-costs-coverage/system/v1/token'

      def settings
        Settings.lighthouse.healthcare_cost_and_coverage
      end

      def base_path(host = nil)
        (host || settings.host).to_s
      end

      def base_api_path(host = nil)
        "#{base_path(host)}/#{API_PATH}"
      end

      def service_name
        'HealthcareCostAndCoverage'
      end

      def get(path, options = {})
        connection.get(path, options[:params], { 'Authorization' => "Bearer #{access_token(options)}" })
      end

      def post(path, body, options = {})
        connection.post(path, body, { 'Authorization' => "Bearer #{access_token(options)}" })
      end

      def connection
        @conn ||= Faraday.new(base_api_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use(:breakers, service_name:)
          faraday.use Faraday::Response::RaiseError

          faraday.response :json, content_type: /\bjson\b/

          faraday.response :betamocks if settings.use_mocks

          faraday.adapter Faraday.default_adapter
        end
      end

      private

      def base_request_headers
        super.merge('Accept' => 'application/json+fhir')
      end

      def access_token(options = {})
        return nil if settings.use_mocks && !Settings.betamocks.recording

        token_service(
          options[:client_id],
          options[:rsa_key],
          options[:aud_claim_url],
          options[:host],
          options[:scopes]
        ).get_token(auth_params(options))
      end

      def auth_params(options)
        icn = options[:icn]
        raise ArgumentError, 'icn is required to mint a HCCC token' if icn.blank?

        launch = Base64.strict_encode64({ patient: icn }.to_json)
        { launch: }
      end

      def token_service(client_id, rsa_key, aud_claim_url = nil, host = nil, scopes = nil)
        s = settings
        host ||= base_path
        url = "#{host}/#{TOKEN_PATH}"

        client_id ||= s.access_token.client_id
        rsa_key ||= s.access_token.rsa_key
        aud_claim_url ||= s.access_token.aud_claim_url
        scopes ||= Array(s.scopes)

        # no memoization; let Redis cache the token
        Auth::ClientCredentials::Service.new(
          url, scopes, client_id, aud_claim_url, rsa_key, 'hccc'
        )
      end
    end
  end
end
