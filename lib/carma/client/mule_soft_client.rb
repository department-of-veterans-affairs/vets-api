# frozen_string_literal: true

require 'carma/client/mule_soft_configuration'

module CARMA
  module Client
    class MuleSoftClient < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      configuration MuleSoftConfiguration

      STATSD_KEY_PREFIX = 'api.carma.mulesoft'

      # @param payload [String] JSON payload to submit
      # @return [Faraday::Env]
      def create_submission(payload)
        do_post('submit', payload)
      end

      # @param payload [String] JSON payload to submit
      # @return [Faraday::Env]
      def upload_attachments(payload)
        do_post('addDocument', payload)
      end

      private

      # @param resource [String] REST-ful path component
      # @param payload [String] JSON payload to submit
      # @return [Hash]
      def do_post(resource, payload)
        with_monitoring do
          Rails.logger.info "[Form 10-10CG] Submitting to '#{resource}'"
          args = post_args(resource, payload)
          resp = perform(*args)
          raise_error_unless_success(resource, resp.status)
          JSON.parse(resp.body)
        end
      end

      # @return [Array]
      def post_args(resource, payload)
        body = payload.is_a?(String) ? payload : payload.to_json
        headers = config.base_request_headers
        opts = { timeout: config.timeout }
        [:post, resource, body, headers, opts]
      end

      def raise_error_unless_success(resource, status)
        Rails.logger.info "[Form 10-10CG] Submission to '#{resource}' resource resulted in response code #{status}"
        return if status == 200

        raise Common::Exceptions::SchemaValidationErrors, ["Expecting 200 status but received #{status}"]
      end
    end
  end
end
