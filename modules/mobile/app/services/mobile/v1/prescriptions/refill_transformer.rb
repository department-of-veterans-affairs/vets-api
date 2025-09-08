# frozen_string_literal: true

module Mobile
  module V1
    module Prescriptions
      class RefillTransformer
        def transform(uhd_refill_response)
          # Transform UHD refill response to match v0 API structure
          # UHD response format: { success: [...], failed: [...] }
          # V0 API format: { failed_station_list: [...], successful_station_list: [...], ... }
          
          {
            failed_station_list: extract_failed_stations(uhd_refill_response[:failed]),
            successful_station_list: extract_successful_stations(uhd_refill_response[:success]),
            last_updated_time: Time.current.iso8601,
            prescription_list: build_prescription_list(uhd_refill_response),
            failed_prescription_ids: extract_failed_prescription_ids(uhd_refill_response[:failed]),
            errors: build_errors(uhd_refill_response[:failed]),
            info_messages: build_info_messages(uhd_refill_response)
          }
        end

        private

        def extract_failed_stations(failed_prescriptions)
          return [] if failed_prescriptions.blank?

          failed_prescriptions.map { |failure| extract_station_from_id(failure[:id]) }.uniq.compact
        end

        def extract_successful_stations(successful_prescriptions)
          return [] if successful_prescriptions.blank?

          successful_prescriptions.map { |success| extract_station_from_id(success[:id]) }.uniq.compact
        end

        def extract_station_from_id(prescription_id)
          # Extract station number from prescription ID if available
          # This may need adjustment based on actual UHD prescription ID format
          prescription_id.to_s.first(3) if prescription_id
        end

        def build_prescription_list(uhd_response)
          prescription_list = []

          # Add successful prescriptions
          if uhd_response[:success].present?
            uhd_response[:success].each do |success|
              prescription_list << {
                prescription_id: success[:id],
                prescription_number: success[:id],
                prescription_name: success[:name] || 'Unknown',
                station_number: extract_station_from_id(success[:id]),
                success: true
              }
            end
          end

          # Add failed prescriptions
          if uhd_response[:failed].present?
            uhd_response[:failed].each do |failure|
              prescription_list << {
                prescription_id: failure[:id],
                prescription_number: failure[:id],
                prescription_name: failure[:name] || 'Unknown',
                station_number: extract_station_from_id(failure[:id]),
                success: false,
                error_message: failure[:error]
              }
            end
          end

          prescription_list
        end

        def extract_failed_prescription_ids(failed_prescriptions)
          return [] if failed_prescriptions.blank?

          failed_prescriptions.map { |failure| failure[:id] }.compact
        end

        def build_errors(failed_prescriptions)
          return [] if failed_prescriptions.blank?

          failed_prescriptions.map do |failure|
            {
              developer_message: "Prescription ID: #{failure[:id]} - #{failure[:error]}",
              prescription_id: failure[:id],
              error_code: 'REFILL_ERROR'
            }
          end
        end

        def build_info_messages(uhd_response)
          messages = []

          if uhd_response[:success].present?
            messages << "Successfully submitted #{uhd_response[:success].size} prescription(s) for refill"
          end

          if uhd_response[:failed].present?
            messages << "Failed to submit #{uhd_response[:failed].size} prescription(s) for refill"
          end

          messages
        end
      end
    end
  end
end
