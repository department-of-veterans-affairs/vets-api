# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class MilitaryInformation
        def parse(user_uuid, military_information)
          formatted_result = []

          military_information.each do |service_period|
            if service_period[:service_type] == 'Military Service'
              service_period = format_service_period(service_period)
              formatted_result.push(service_period)
            end
          end
          OpenStruct.new({ id: user_uuid, service_history: formatted_result })
        end

        private

        def format_service_period(service_period)
          Mobile::V0::MilitaryInformation.new(
            branch_of_service: "United States #{service_period[:branch_of_service].titleize}",
            begin_date: service_period[:begin_date],
            end_date: service_period[:end_date].presence,
            formatted_begin_date: service_period[:begin_date].to_datetime.strftime('%B %d, %Y'),
            formatted_end_date: service_period[:end_date]&.to_datetime&.strftime('%B %d, %Y').presence
          )
        end
      end
    end
  end
end
