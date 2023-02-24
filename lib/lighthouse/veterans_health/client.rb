# frozen_string_literal: true

require 'lighthouse/veterans_health/configuration'
require 'lighthouse/veterans_health/jwt_wrapper'

# This client was written to work for the specific use case of the
# VA OCTO's hypertension fast track pilot, which is located in a Sidekiq job that is kicked off
# one-to-one for each veteran 526 claim for increase submitted in va.gov
# If you're looking for a more generic Veterans Health Lighthouse client that doesn't instantiate
# with a set ICN, consider creating/using another client
module Lighthouse
  module VeteransHealth
    # Documentation located at:
    # https://developer.va.gov/explore/health/docs/fhir?version=current
    class Client < Common::Client::Base
      include Common::Client::Concerns::Monitoring
      configuration Lighthouse::VeteransHealth::Configuration

      # Initializes the Veterans Health client.
      #
      # @example
      #
      # Lighthouse::VeteransHealth::Client.new('12345')
      #
      # @param [String] icn The ICN of the veteran filing the 526 claim for increase
      #
      # @return [Lighthouse::VeteransHealth::Client]
      def initialize(icn)
        @icn = icn
        raise ArgumentError, 'no ICN passed in for LH API request.' if icn.blank?
      end

      def list_bp_observations
        params = {
          category: 'vital-signs',
          code: '85354-9'
        }
        list_observations(params)
      end

      def list_conditions
        params = {
          patient: @icn,
          _count: 100
        }

        first_response = perform_get('services/fhir/v0/r4/Condition', **params)
        get_list(first_response)
      end

      def list_observations(params_override = {})
        params = {
          patient: @icn,
          _count: 100
        }.merge(params_override)

        first_response = perform_get('services/fhir/v0/r4/Observation', **params)
        get_list(first_response)
      end

      def list_medication_requests
        params = {
          patient: @icn,
          _count: 100
        }
        first_response = perform_get('services/fhir/v0/r4/MedicationRequest', **params)
        get_list(first_response)
      end

      private

      # @return Faraday::Env response with all the pages of data
      def get_list(first_response)
        next_page = first_response.body['link'].find { |link| link['relation'] == 'next' }&.[]('url')
        return first_response unless next_page

        first_response.body['entry'] = collect_all_entries(next_page, first_response.body['entry'])
        first_response
      end

      def collect_all_entries(next_page, collection)
        while next_page.present?
          next_response = perform_get(URI(next_page).path + "?#{URI(next_page).query}")
          collection.concat(next_response.body['entry'])
          next_page = next_response.body['link'].find { |link| link['relation'] == 'next' }&.[]('url')
        end

        collection
      end

      def perform_get(uri_path, **params)
        perform(:get, uri_path, params, headers_hash)
      end

      def authenticate(params)
        perform(
          :post,
          'oauth2/health/system/v1/token',
          URI.encode_www_form(params),
          { 'Content-Type': 'application/x-www-form-urlencoded' }
        )
      end

      def base64_icn
        @base64_icn ||= Base64.encode64 JSON.generate({ patient: @icn.to_s }, space: ' ')
      end

      def bearer_token
        @bearer_token ||= retrieve_bearer_token
      end

      def headers_hash
        @headers_hash ||= Configuration.base_request_headers.merge({ Authorization: "Bearer #{bearer_token}" })
      end

      def retrieve_bearer_token
        authenticate_as_system(JwtWrapper.new.token)
      end

      def authenticate_as_system(json_web_token)
        authenticate(payload(json_web_token)).body['access_token']
      end

      def payload(json_web_token)
        {
          grant_type: 'client_credentials',
          client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
          client_assertion: json_web_token,
          scope: Settings.lighthouse.veterans_health.fast_tracker.api_scope.join(' '),
          launch: base64_icn
        }.as_json
      end
    end
  end
end
