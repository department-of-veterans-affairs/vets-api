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

      def build_prescription_attributes(medication)
        tracking_data = build_tracking_information(medication)

        build_core_attributes(medication)
          .merge(build_tracking_attributes(tracking_data))
          .merge(build_contact_and_source_attributes(medication))
      end

      def build_core_attributes(medication)
        {
          id: medication['prescriptionId'].to_s,
          type: 'Prescription',
          refill_status: medication['refillStatus'],
          refill_submit_date: convert_to_iso8601(medication['refillSubmitDate'], field_name: 'refill_submit_date'),
          refill_date: convert_to_iso8601(medication['refillDate'], field_name: 'refill_date'),
          refill_remaining: medication['refillRemaining'],
          facility_name: medication['facilityName'],
          ordered_date: convert_to_iso8601(medication['orderedDate'], field_name: 'ordered_date'),
          quantity: medication['quantity'],
          expiration_date: convert_to_iso8601(medication['expirationDate'], field_name: 'expiration_date'),
          prescription_number: medication['prescriptionNumber'],
          prescription_name: medication['prescriptionName'].presence || medication['orderableItem'],
          dispensed_date: convert_to_iso8601(medication['dispensedDate'], field_name: 'dispensed_date'),
          station_number: medication['stationNumber'],
          is_refillable: medication['isRefillable']
        }
      end

      def build_tracking_attributes(tracking_data)
        {
          is_trackable: tracking_data.any?,
          tracking: tracking_data
        }
      end

      def build_contact_and_source_attributes(medication)
        {
          instructions: medication['sig'],
          facility_phone_number: medication['cmopDivisionPhone'],
          prescription_source: medication['prescriptionSource']
        }
      end

      def build_tracking_information(medication)
        tracking_info = medication['trackingInfo'] || []
        return [] unless tracking_info.is_a?(Array)

        tracking_info.map do |tracking|
          {
            prescription_name: medication['prescriptionName'],
            prescription_number: medication['prescriptionNumber'],
            ndc_number: medication['ndcNumber'],
            prescription_id: medication['prescriptionId'],
            tracking_number: tracking['trackingNumber'],
            shipped_date: format_shipped_date(tracking['shippedDate']),
            carrier: tracking['deliveryService'],
            other_prescriptions: build_other_prescriptions(tracking['otherPrescriptionListIncluded'] || [])
          }
        end
      end

      def format_shipped_date(date_string)
        convert_to_iso8601(date_string, field_name: 'shipped_date')
      end

      def build_other_prescriptions(other_prescriptions)
        return [] unless other_prescriptions.is_a?(Array)

        other_prescriptions.map do |prescription|
          {
            prescription_name: prescription['prescriptionName'],
            prescription_number: prescription['prescriptionNumber'],
            ndc_number: prescription['ndcNumber'],
            station_number: prescription['stationNumber']
          }
        end
      end

      def convert_to_iso8601(date_string, field_name:)
        return nil if date_string.blank?

        Time.parse(date_string.to_s).utc.iso8601(3)
      rescue ArgumentError => e
        Rails.logger.warn("Failed to parse #{field_name} '#{date_string}': #{e.message}")
        date_string
      end
    end
  end
end
