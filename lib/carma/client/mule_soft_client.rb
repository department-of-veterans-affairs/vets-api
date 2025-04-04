# frozen_string_literal: true

require 'carma/client/mule_soft_configuration'
require 'carma/client/mule_soft_auth_token_client'

module CARMA
  module Client
    class MuleSoftClient < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      configuration MuleSoftConfiguration

      STATSD_KEY_PREFIX = 'api.carma.mulesoft'

      class RecordParseError < StandardError; end

      def create_submission_v2(payload)
        with_monitoring do
          res = perform_post(payload)

          raise RecordParseError if res.dig('record', 'hasErrors')

          res
        end
      end

      private

      def perform_post(payload)
        resource = 'v2/application/1010CG/submit'
        with_monitoring do
          Rails.logger.info "[Form 10-10CG] Submitting to '#{resource}' using bearer token"

          response = perform(
            :post,
            resource,
            get_body(payload),
            headers,
            { timeout: config.settings.async_timeout }
          )

          handle_response(resource, response)
        end
      end

      def bearer_token
        @bearer_token ||= CARMA::Client::MuleSoftAuthTokenClient.new.new_bearer_token
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

      def handle_response(resource, response)
        Sentry.set_extras(response_body: response.body)
        raise_error_unless_success(resource, response.status)
        JSON.parse(response.body)
      end

      def raise_error_unless_success(resource, status)
        Rails.logger.info "[Form 10-10CG] Submission to '#{resource}' resource resulted in response code #{status}"
        return if [200, 201, 202].include? status

        raise Common::Exceptions::SchemaValidationErrors, ["Expecting 200 status but received #{status}"]
      end
    end
  end
end
