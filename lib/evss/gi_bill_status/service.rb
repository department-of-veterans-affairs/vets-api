# frozen_string_literal: true
module EVSS
  module GiBillStatus
    class Service < EVSS::Service
      BASE_URL = EVSS::GiBillStatus::Configuration::BASE_URL

      configuration EVSS::GiBillStatus::Configuration


      def initialize(current_user)
        @current_user = current_user
      end

      def get_gi_bill_status
        raw_response = perform_with_user_headers(:get, '', nil)
        EVSS::GiBillStatus::GiBillStatusResponse.new(raw_response.status, raw_response)
      rescue Faraday::ParsingError => e
        response = OpenStruct.new(e.response.to_hash)
        content_type = response.response_headers['content-type']
        extra_context = { response: response }
        log_exception_to_sentry(e, extra_context)
        EVSS::GiBillStatus::GiBillStatusResponse.new(response.status, response, false, content_type)
      rescue Common::Exceptions::GatewayTimeout
        EVSS::GiBillStatus::GiBillStatusResponse.new(999, nil, true)
      rescue Common::Client::Errors::ClientError => e
        response = OpenStruct.new(
          body: e.body,
          status: e.status
        )

        extra_context = { url: BASE_URL, response: response }
        log_exception_to_sentry(e, extra_context)
        EVSS::GiBillStatus::GiBillStatusResponse.new(response.status, response)
      end
    end
  end
end
