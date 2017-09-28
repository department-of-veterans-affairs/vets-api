# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  module GiBillStatus
    class Service < EVSS::Service
      configuration EVSS::GiBillStatus::Configuration

      def get_gi_bill_status
        raw_response = get ''
        EVSS::GiBillStatus::GiBillStatusResponse.new(raw_response.status, raw_response)
      rescue Faraday::ParsingError => e
        response = OpenStruct.new(e.response.to_hash)
        content_type = response.response_headers['content-type']
        extra_context = { response: response }
        log_exception_to_sentry(e, extra_context)
        EVSS::GiBillStatus::GiBillStatusResponse.new(response.status, response, false, content_type)
      rescue Faraday::TimeoutError
        log_message_to_sentry(
          'Timeout while connecting to GiBillStatus service', :error, extra_context: { url: BASE_URL }
        )
        EVSS::GiBillStatus::GiBillStatusResponse.new(999, nil, true)
      rescue Faraday::ClientError => e
        # convert <Faraday::ClientError>.response hash to object to conform with a normal response
        response = OpenStruct.new(e&.response)

        extra_context = { url: BASE_URL, response: response }
        log_exception_to_sentry(e, extra_context)
        EVSS::GiBillStatus::GiBillStatusResponse.new(response.status, response)
      end

      def self.breakers_service
        BaseService.create_breakers_service(name: 'EVSS/GiBillStatus', url: BASE_URL)
      end
    end
  end
end
