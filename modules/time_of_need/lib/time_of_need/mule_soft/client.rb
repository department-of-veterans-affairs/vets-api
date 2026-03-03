# frozen_string_literal: true

require 'common/client/base'
require 'time_of_need/mule_soft/configuration'
require 'time_of_need/mule_soft/auth_token_client'

module TimeOfNeed
  module MuleSoft
    ##
    # HTTP client for submitting Time of Need claims to NCA's MuleSoft API.
    #
    # Authenticates via OAuth2 client credentials (bearer token) and POSTs
    # structured form data + file attachments to the MuleSoft endpoint.
    #
    # Data flow: vets-api → MuleSoft → MDW → CaMEO (Salesforce)
    #
    # TODO: Implement once we have from the MuleSoft team:
    #   - Endpoint URL and resource path
    #   - Expected payload schema (JSON structure)
    #   - File format preference (base64 inline vs multipart)
    #   - OAuth2 credentials
    #
    class Client < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      STATSD_KEY_PREFIX = 'api.time_of_need.mulesoft'

      configuration TimeOfNeed::MuleSoft::Configuration

      ##
      # Submit a claim payload to MuleSoft
      #
      # @param payload [Hash] the structured form data
      # @return [Hash] parsed response from MuleSoft
      # @raise [StandardError] on submission failure
      def submit(payload)
        with_monitoring do
          response = perform(
            :post,
            resource_path,
            get_body(payload),
            headers
          )

          handle_response(response)
        end
      end

      private

      ##
      # The API resource path for ToN submissions
      # TODO: Update once endpoint is confirmed
      def resource_path
        'v1/time-of-need/submit'
      end

      def bearer_token
        @bearer_token ||= TimeOfNeed::MuleSoft::AuthTokenClient.new.new_bearer_token
      end

      def headers
        {
          'Authorization' => "Bearer #{bearer_token}",
          'Content-Type' => 'application/json'
        }
      end

      def get_body(payload)
        payload.is_a?(String) ? payload : payload.to_json
      end

      def handle_response(response)
        raise_error_unless_success(response.status)
        JSON.parse(response.body)
      end

      def raise_error_unless_success(status)
        Rails.logger.info "[TimeOfNeed] MuleSoft submission response: #{status}"
        return if [200, 201, 202].include? status

        Rails.logger.error "[TimeOfNeed] MuleSoft submission expected 200 but received #{status}"
        raise Common::Exceptions::SchemaValidationErrors, ["Expecting 200 status but received #{status}"]
      end
    end
  end
end
