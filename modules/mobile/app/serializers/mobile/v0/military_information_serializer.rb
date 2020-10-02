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
          service_period[:branch_of_service] = 'United States ' + service_period[:branch_of_service]
          service_period[:formatted_begin_date] = service_period[:begin_date].strftime('%B %d, %Y')
          service_period[:formatted_end_date] = service_period[:end_date].strftime('%B %d, %Y')
          service_period = service_period.except(:personnel_category_type_code)
          formatted_result.push(service_period)
        end
        formatted_result
      end
    end
  end
end
