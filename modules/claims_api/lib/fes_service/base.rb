# frozen_string_literal: true

require 'claims_api/claim_logger'
require 'common/client/errors'
require 'custom_error'
require 'claims_api/v2/form526_establishment_service/service'

module ClaimsApi
  module FesService
    class Base
      def initialize(request = nil, use_mock: nil)
        @request = request
        @auth_headers = {}
        @use_mock = use_mock.nil? ? Rails.env.test? : use_mock
      end

      #  rubocop:disable Style/OptionalBooleanParameter
      def validate(claim, claim_data, async = false)
        @async = async
        @auth_headers = claim.auth_headers
        request_body = claim_data

        begin
          body = client.post('validate', request_body)&.body
          log_outcome_for_claims_api('validate', 'raw_response', body, claim)
          response = parse_fes_response(body)
          log_outcome_for_claims_api('validate', 'success', response, claim)

          response
        rescue => e
          detail = get_error_message(e)
          log_outcome_for_claims_api('validate', 'error', detail, claim)

          error_handler(e, detail)
        end
      end
      # rubocop:enable Style/OptionalBooleanParameter

      # rubocop:disable Style/OptionalBooleanParameter
      def submit(claim, claim_data, async = false)
        @async = async
        @auth_headers = claim.auth_headers
        request_body = claim_data

        begin
          body = client.post('submit', request_body)&.body
          log_outcome_for_claims_api('submit', 'raw_response', body, claim)
          response = parse_fes_response(body)
          log_outcome_for_claims_api('submit', 'success', response, claim)

          response
        rescue => e
          detail = get_error_message(e)
          log_outcome_for_claims_api('submit', 'error', detail, claim)

          error_handler(e, detail)
        end
      end
      # rubocop:enable Style/OptionalBooleanParameter

      private

      def client
        hostname = Settings.claims_api.fes.service_url
        raise StandardError, 'FES host URL missing' if hostname.blank?

        base_url = "#{hostname}/form526-establishment-service/v1"

        Faraday.new(base_url,
                    ssl: { verify: Settings.claims_api&.fes&.ssl != false },
                    headers:) do |f|
          f.request :json
          f.response :betamocks if @use_mock
          f.response :raise_custom_error
          f.response :json, parser_options: { symbolize_names: true }
          f.adapter Faraday.default_adapter
        end
      end

      def headers
        @auth_headers.merge!({
                               Authorization: "Bearer #{access_token}",
                               'content-type': 'application/json; charset=UTF-8'
                             })
        @auth_headers.transform_keys(&:to_s)
      end

      def access_token
        return 'fake_token' if @use_mock

        @fes_auth_token ||= ClaimsApi::V2::Form526EstablishmentService::Service.new.get_auth_token
        raise StandardError, 'FES auth token missing' if @fes_auth_token.blank?

        @fes_auth_token
      end

      def log_outcome_for_claims_api(action, status, response, claim)
        ClaimsApi::Logger.log('fes_service', detail: "FES #{action} #{status}: #{response}",
                                             claim: claim&.id, transaction_id: claim&.transaction_id)
      end

      def error_handler(error, detail)
        ClaimsApi::CustomError.new(error, detail, @async).build_error
      end

      def get_error_message(error)
        if error.respond_to?(:original_body) && error.original_body.present?
          error.original_body
        elsif error.respond_to?(:body) && error.body.present?
          error.body
        elsif error.respond_to?(:message) && error.message.present?
          error.message
        elsif error.respond_to?(:errors) && error.errors.present?
          error.errors
        elsif error.respond_to?(:detailed_message) && error.detailed_message.present?
          error.detailed_message
        else
          error
        end
      end

      def parse_fes_response(response)
        unless response.is_a?(Hash)
          # Being cautious of possible html return issue with EVSS / deep_symbolize_keys error handling
          raise ::Common::Client::Errors::ParsingError,
                'FES service returned an unexpected response format'
        end

        response[:data] || response['data'] || response
      end
    end
  end
end
