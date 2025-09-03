# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    class VistaPrescriptionAdapter
      def parse(medication)
        return nil if medication.nil? || medication['prescriptionId'].nil?

        attributes = UnifiedHealthData::PrescriptionAttributes.new({
          refill_status: medication['refillStatus'],
          refill_submit_date: medication['refillSubmitDate'],
          refill_date: medication['refillDate'],
          refill_remaining: medication['refillRemaining'],
          facility_name: medication['facilityName'],
          ordered_date: medication['orderedDate'],
          quantity: medication['quantity'],
          expiration_date: medication['expirationDate'],
          prescription_number: medication['prescriptionNumber'],
          prescription_name: medication['prescriptionName'],
          dispensed_date: medication['dispensedDate'],
          station_number: medication['stationNumber'],
          is_refillable: medication['isRefillable'],
          is_trackable: medication['isTrackable'],
          instructions: medication['sig'],
          facility_phone_number: medication['cmopDivisionPhone'],
          data_source_system: medication['dataSourceSystem'] || 'VISTA'
        })

        UnifiedHealthData::Prescription.new({
          id: medication['prescriptionId'].to_s,
          type: 'Prescription',
          attributes: attributes
        })
      rescue => e
        Rails.logger.error("Error parsing VistA prescription: #{e.message}")
        nil
      end
    end
  end
end