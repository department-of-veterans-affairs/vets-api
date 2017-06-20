# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  module GiBillStatus
    class Service < EVSS::BaseService
      BASE_URL = "#{Settings.evss.url}/wss-education-services-web/rest/education/chapter33/v1"

      def get_gi_bill_status
        raw_response = get ''
        EVSS::GiBillStatus::GiBillStatusResponse.new(raw_response.status, raw_response)
      rescue Faraday::ParsingError
        EVSS::GiBillStatus::GiBillStatusResponse.new(403)
      rescue Faraday::ClientError => e
        EVSS::GiBillStatus::GiBillStatusResponse.new(e.response[:status])
      end
    end
  end
end
