# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  module GiBillStatus
    class Service < EVSS::BaseService
      BASE_URL = "#{Settings.evss.url}/wss-education-services-web/rest/education/chapter33/v1"

      def get_gi_bill_status
        puts "A"
        raw_response = get ''
        puts raw_response.inspect
        EVSS::GiBillStatus::GiBillStatusResponse.new(raw_response.status, raw_response)
      rescue Faraday::ParsingError
        puts "B"
        EVSS::GiBillStatus::GiBillStatusResponse.new(403)
      rescue Faraday::ClientError => e
        puts "C"
        EVSS::GiBillStatus::GiBillStatusResponse.new(e.response[:status])
      rescue => e
        puts e.inspect
        puts "D"
        EVSS::GiBillStatus::GiBillStatusResponse.new(500)
      end
    end
  end
end
