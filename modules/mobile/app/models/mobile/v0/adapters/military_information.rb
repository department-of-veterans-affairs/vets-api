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

          Mobile::V0::MilitaryInformationHistory.new({ id: user_uuid, service_history: formatted_result })
        end

        private

        DISCHARGE_CODE_MAP = {
          'A' => {
            name: 'Honorable',
            indicator: 'Y'
          },
          'B' => {
            name: 'Under honorable conditions (general)',
            indicator: 'Y'
          },
          'D' => {
            name: 'Bad conduct',
            indicator: 'N'
          },
          'E' => {
            name: 'Under other than honorable conditions',
            indicator: 'N'
          },
          'F' => {
            name: 'Dishonorable',
            indicator: 'N'
          },
          'H' => {
            name: 'Honorable (Assumed) - GRAS periods only',
            indicator: 'Y'
          },
          'J' => {
            name: 'Honorable for VA purposes',
            indicator: 'Y'
          },
          'K' => {
            name: 'Dishonorable for VA purposes',
            indicator: 'N'
          },
          'Y' => {
            name: 'Uncharacterized',
            indicator: 'Z'
          },
          'Z' => {
            name: 'Unknown',
            indicator: 'Z'
          },
          'DVN' => {
            name: 'DoD provided a NULL or blank value',
            indicator: 'Z'
          },
          'DVU' => {
            name: 'DoD provided a value not in the reference table',
            indicator: 'Z'
          },
          'CVI' => {
            name: 'Value is calculated but created an invalid value',
            indicator: 'Z'
          },
          'VNA' => {
            name: 'Value is not applicable for this record type',
            indicator: 'Z'
          }
        }.freeze

        def format_service_period(service_period)
          discharge_section = discharge_code_section(service_period)
          Mobile::V0::MilitaryInformation.new(
            branch_of_service: "United States #{service_period[:branch_of_service].titleize}",
            begin_date: service_period[:begin_date],
            end_date: service_period[:end_date].presence,
            formatted_begin_date: service_period[:begin_date].to_datetime.strftime('%B %d, %Y'),
            formatted_end_date: service_period[:end_date]&.to_datetime&.strftime('%B %d, %Y').presence,
            character_of_discharge: discharge_section&.dig(:name),
            honorable_service_indicator: discharge_section&.dig(:indicator)
          )
        end

        def discharge_code_section(service_period)
          discharge_code = service_period[:character_of_discharge_code]
          DISCHARGE_CODE_MAP[discharge_code]
        end
      end
    end
  end
end
