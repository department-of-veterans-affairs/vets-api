# frozen_string_literal: true

require 'claims_api/v2/benefits_documents/service'
require 'claims_api/claim_logger'
require 'common/client/errors'
require 'custom_error'

module ClaimsApi
  ##
  # Class to interact with the EVSS container
  #
  # Takes an optional request parameter
  # @param [] rails request object (used to determine environment)
  module EVSSService
    class Base
      def initialize(request = nil)
        @request = request
        @auth_headers = {}
        @use_mock = Settings.evss.mock_claims || false
      end

      def submit(claim, data)
        @auth_headers = claim.auth_headers

        begin
          resp = client.post('submit', data)&.body&.deep_symbolize_keys
          log_outcome_for_claims_api('submit', 'success', resp, claim)
          resp # return is for v1 Sidekiq worker
        rescue => e
          error_handler(e, false)
        end
      end

      def validate(claim, data)
        @auth_headers = claim.auth_headers

        begin
          resp = client.post('validate', data)&.body&.deep_symbolize_keys
          log_outcome_for_claims_api('validate', 'success', resp, claim)

          resp
        rescue => e
          detail = e.respond_to?(:original_body) ? e.original_body : e
          log_outcome_for_claims_api('validate', 'error', detail, claim)

          error_handler(e, false)
        end
      end

      private

      def client
        base_name = Settings.evss&.dvp&.url
        service_name = Settings.evss&.service_name

        raise StandardError, 'DVP URL missing' if base_name.blank?

        Faraday.new("#{base_name}/#{service_name}/rest/form526/v2",
                    # Disable SSL for (localhost) testing
                    ssl: { verify: Settings.evss&.dvp&.ssl != false },
                    headers:) do |f|
          f.request :json
          f.response :betamocks if @use_mock
          f.response :raise_error
          f.response :json, parser_options: { symbolize_names: true }
          f.adapter Faraday.default_adapter
        end
      end

      def headers
        return @auth_headers if @use_mock # no sense in getting a token if the target request is mocked

        client_key = Settings.claims_api.evss_container&.client_key || ENV.fetch('EVSS_CLIENT_KEY', '')
        raise StandardError, 'EVSS client_key missing' if client_key.blank?

        @auth_headers.merge!({
                               Authorization: "Bearer #{access_token}",
                               'client-key': client_key,
                               'content-type': 'application/json; charset=UTF-8'
                             })
        @auth_headers.transform_keys(&:to_s)
      end

      def access_token
        @auth_token ||= ClaimsApi::V2::BenefitsDocuments::Service.new.get_auth_token
      end

      def log_outcome_for_claims_api(action, status, response, claim)
        ClaimsApi::Logger.log('526_docker_container',
                              detail: "EVSS DOCKER CONTAINER #{action} #{status}: #{response}", claim: claim&.id)
      end

      def custom_error(error, async: true)
        ClaimsApi::CustomError.new(error, async)
      end

      def error_handler(error, async: true)
        custom_error(error, async).build_error
      end
    end
  end
end
