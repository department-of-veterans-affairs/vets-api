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
          is_trackable: medication['isTrackable'] || false,
          tracking: build_tracking_array(medication),
          instructions: medication['sig'],
          cmop_division_phone: medication['cmopDivisionPhone'],
          prescription_source: medication['prescriptionSource']
        }
      end
      # rubocop:enable Metrics/MethodLength

      def build_tracking_array(medication)
        return [] unless medication['trackingInfo'].is_a?(Array)

        medication['trackingInfo'].map do |tracking_info|
          {
            prescriptionName: medication['prescriptionName'],
            prescriptionNumber: medication['prescriptionNumber'],
            ndcNumber: medication['ndcNumber'],
            prescriptionId: medication['prescriptionId']&.to_i,
            trackingNumber: tracking_info['trackingNumber'],
            shippedDate: format_shipped_date(tracking_info['shippedDate']),
            carrier: tracking_info['deliveryService'],
            otherPrescriptions: build_other_prescriptions(tracking_info['otherPrescriptionListIncluded'])
          }
        end
      end

      def format_shipped_date(shipped_date)
        return nil unless shipped_date

        # Convert from "Wed, 07 Sep 2016 00:00:00 EDT" to "2016-09-07T00:00:00.000Z"
        parsed_date = Time.parse(shipped_date).utc
        parsed_date.iso8601(3)
      rescue StandardError => e
        Rails.logger.warn("Unable to parse shipped date: #{shipped_date}, error: #{e.message}")
        nil
      end

      def build_other_prescriptions(other_prescriptions_list)
        return [] unless other_prescriptions_list.is_a?(Array)

        other_prescriptions_list.map do |prescription|
          {
            prescriptionName: prescription['prescriptionName'],
            prescriptionNumber: prescription['prescriptionNumber']
          }
        end
      end
    end
  end
end
