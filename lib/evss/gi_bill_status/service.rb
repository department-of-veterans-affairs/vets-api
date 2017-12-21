# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  module GiBillStatus
    class Service < EVSS::Service
      configuration EVSS::GiBillStatus::Configuration

      def get_gi_bill_status
        raw_response = perform(:get, '')
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
      rescue Common::Client::Errors::ClientError => e
        response = OpenStruct.new(status: e.status, body: e.body)

        extra_context = { url: config.base_path, response: response }
        log_exception_to_sentry(e, extra_context)
        EVSS::GiBillStatus::GiBillStatusResponse.new(response.status, response)
      end
    end
  end
end
