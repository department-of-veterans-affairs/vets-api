# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    class VistaPrescriptionAdapter
      # Parses a VistA medication record into a UnifiedHealthData::Prescription
      #
      # @param medication [Hash] Raw medication data from VistA
      # @return [UnifiedHealthData::Prescription, nil] Parsed prescription or nil if invalid
      def parse(medication)
        return nil if medication.nil? || medication['prescriptionId'].nil?

        UnifiedHealthData::Prescription.new(build_prescription_attributes(medication))
      rescue => e
        Rails.logger.error("Error parsing VistA prescription: #{e.message}")
        nil
      end

      private

      # rubocop:disable Metrics/MethodLength
      def build_prescription_attributes(medication)
        {
          id: medication['prescriptionId'].to_s,
          type: 'Prescription',
          refill_status: medication['refillStatus'],
          refill_submit_date: medication['refillSubmitDate'],
          refill_date: medication['refillDate'],
          refill_remaining: medication['refillRemaining'],
          facility_name: medication['facilityName'],
          ordered_date: medication['orderedDate'],
          quantity: medication['quantity'],
          expiration_date: medication['expirationDate'],
          prescription_number: medication['prescriptionNumber'],
          prescription_name: medication['prescriptionName'].presence || medication['orderableItem'],
          dispensed_date: medication['dispensedDate'],
          station_number: medication['stationNumber'],
          is_refillable: medication['isRefillable'],
          # TODO: update when adding tracking info to VistA response
          is_trackable: false,
          instructions: medication['sig'],
          cmop_division_phone: medication['cmopDivisionPhone'],
          prescription_source: medication['prescriptionSource']
        }
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
