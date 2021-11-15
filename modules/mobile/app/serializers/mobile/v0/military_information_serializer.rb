# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class MilitaryInformationSerializer
      include FastJsonapi::ObjectSerializer

      set_type :militaryInformation
      attribute :service_history do |user|
        formatted_result = []
        user.military_information.service_history.each do |service_period|
          service_period = format_service_period(service_period)
          formatted_result.push(service_period) unless service_period.nil?
        end
        formatted_result
      end

      def self.format_service_period(service_period)
        if service_period[:branch_of_service].nil?
          Rails.logger.warn(
            'mobile military information missing service period details', service_period: service_period
          )
          return nil
        end

        service_period[:branch_of_service] = "United States #{service_period[:branch_of_service].titleize}"
        service_period[:formatted_begin_date] = service_period[:begin_date].strftime('%B %d, %Y')
        service_period[:formatted_end_date] = service_period[:end_date]&.strftime('%B %d, %Y')

        service_period.except(:personnel_category_type_code)
      end
    end
  end
end
