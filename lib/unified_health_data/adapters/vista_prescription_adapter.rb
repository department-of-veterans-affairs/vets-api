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
        return nil if date_string.blank?

        # Parse the VistA date format "Wed, 07 Sep 2016 00:00:00 EDT" and convert to ISO 8601
        Time.parse(date_string).utc.strftime('%Y-%m-%dT%H:%M:%S.%3NZ')
      rescue ArgumentError => e
        Rails.logger.warn("Failed to parse shipped_date '#{date_string}': #{e.message}")
        date_string # Return original string if parsing fails
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
    end
  end
end
