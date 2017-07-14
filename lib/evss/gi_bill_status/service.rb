# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  module GiBillStatus
    class Service < EVSS::BaseService
      BASE_URL = "#{Settings.evss.url}/wss-education-services-web/rest/education/chapter33/v1"

      def get_gi_bill_status
        raw_response = get ''
        EVSS::GiBillStatus::GiBillStatusResponse.new(raw_response.status, raw_response)
      rescue Faraday::ParsingError => e
        extra_context = { url: BASE_URL }
        log_exception_to_sentry(e, extra_context)
        EVSS::GiBillStatus::GiBillStatusResponse.new(403)
      rescue Faraday::TimeoutError
        log_message_to_sentry(
          'Timeout while connecting to GiBillStatus service', :error, extra_context: { url: BASE_URL }
        )
        EVSS::GiBillStatus::GiBillStatusResponse.new(403)
      rescue Faraday::ClientError => e
        extra_context = { url: BASE_URL, body: e.response[:body] }
        log_exception_to_sentry(e, extra_context)
        EVSS::GiBillStatus::GiBillStatusResponse.new(e.response[:status])
      end
    end

    def self.breakers_service
      BaseService.create_breakers_service(name: 'EVSS/GiBillStatus', url: BASE_URL)
    end
  end
end
