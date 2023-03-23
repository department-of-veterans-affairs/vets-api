# frozen_string_literal: true

require 'carma/client/mule_soft_configuration'

module CARMA
  module Client
    class MuleSoftClient < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      configuration MuleSoftConfiguration

      STATSD_KEY_PREFIX = 'api.carma.mulesoft'

      class RecordParseError < StandardError; end

      def create_submission_v2(payload)
        with_monitoring do
          res = do_post('v2/application/1010CG/submit', payload, config.settings.async_timeout)
          raise RecordParseError if res.dig('record', 'hasErrors')

          res
        end
      end

      private

      # @param resource [String] REST-ful path component
      # @param payload [String] JSON payload to submit
      # @return [Hash]
      def do_post(resource, payload, timeout = config.timeout)
        with_monitoring do
          Rails.logger.info "[Form 10-10CG] Submitting to '#{resource}'"
          args = post_args(resource, payload, timeout)
          resp = perform(*args)
          Raven.extra_context(response_body: resp.body)
          raise_error_unless_success(resource, resp.status)
          JSON.parse(resp.body)
        end
      end

      # @return [Array]
      def post_args(resource, payload, timeout)
        body = payload.is_a?(String) ? payload : payload.to_json
        headers = config.base_request_headers
        opts = { timeout: }
        [:post, resource, body, headers, opts]
      end

      def raise_error_unless_success(resource, status)
        Rails.logger.info "[Form 10-10CG] Submission to '#{resource}' resource resulted in response code #{status}"
        return if [200, 201, 202].include? status

        raise Common::Exceptions::SchemaValidationErrors, ["Expecting 200 status but received #{status}"]
      end
    end
  end
end
