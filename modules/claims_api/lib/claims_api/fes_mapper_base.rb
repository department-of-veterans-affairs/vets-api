# frozen_string_literal: true

module ClaimsApi
  module FesMapperBase
    def map_separation_location_code
      @fes_claim[:serviceInformation][:separationLocationCode] = return_separation_location_code
    end

    def return_separation_location_code
      return_most_recent_service_period&.dig(:separationLocationCode)
    end

    def separation_location_code_present?
      return_most_recent_service_period&.dig(:separationLocationCode).present?
    end

    def return_most_recent_service_period
      @data[:serviceInformation][:servicePeriods]&.max_by do |period|
        Date.parse(period[:activeDutyBeginDate])
      end
    end
  end
end
