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

      # Handles the Lighthouse request for the passed-in resource.
      #
      # @example
      #
      # get_resource('observations')
      #
      # @param [String] resource The Lighthouse resource being requested
      #
      # @return Faraday::Env response
      def get_resource(resource)
        resource = resource.downcase
        raise ArgumentError, 'unsupported resource type' unless %w[medications observations].include?(resource)

        send("get_#{resource}")
      end

      private

      def get_observations
        params = {
          patient: @icn,
          category: 'vital-signs',
          code: '85354-9'
        }

        perform_get('services/fhir/v0/r4/Observation', params)
      end

      def get_medications
        params = {
          patient: @icn
        }
        perform_get('services/fhir/v0/r4/MedicationRequest', params)
      end

      def perform_get(uri_path, params)
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
