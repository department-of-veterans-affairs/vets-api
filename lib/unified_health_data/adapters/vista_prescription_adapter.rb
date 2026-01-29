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
        dispenses_data = build_dispenses_information(medication)

        build_core_attributes(medication)
          .merge(build_tracking_attributes(tracking_data, medication))
          .merge(build_contact_and_source_attributes(medication))
          .merge(dispenses: dispenses_data)
      end

      def build_core_attributes(medication)
        build_identity_attributes(medication).merge(build_prescription_details(medication))
      end

      def build_identity_attributes(medication)
        prescription_id_value = medication['prescriptionId'].to_s
        { id: prescription_id_value, prescription_id: prescription_id_value, type: 'Prescription' }
      end

      def build_prescription_details(medication)
        {
          refill_status: medication['refillStatus'],
          refill_submit_date: convert_to_iso8601(medication['refillSubmitDate'], field_name: 'refill_submit_date'),
          refill_date: convert_to_iso8601(medication['refillDate'], field_name: 'refill_date'),
          refill_remaining: medication['refillRemaining'],
          facility_name: medication['facilityApiName'].presence || medication['facilityName'],
          ordered_date: convert_to_iso8601(medication['orderedDate'], field_name: 'ordered_date'),
          quantity: medication['quantity'],
          expiration_date: convert_to_iso8601(medication['expirationDate'], field_name: 'expiration_date'),
          prescription_number: medication['prescriptionNumber'],
          prescription_name: medication['prescriptionName'].presence || medication['orderableItem'],
          dispensed_date: convert_to_iso8601(medication['dispensedDate'], field_name: 'dispensed_date'),
          station_number: medication['stationNumber'],
          is_refillable: medication['isRefillable'],
          is_renewable: medication['isRenewable'],
          cmop_ndc_number: medication['cmopNdcNumber']
        }
      end

      def build_tracking_attributes(tracking_data, medication)
        {
          is_trackable: medication['isTrackable'] || false,
          tracking: tracking_data
        }
      end

      def build_contact_and_source_attributes(medication)
        {
          instructions: medication['sig'],
          facility_phone_number: medication['cmopDivisionPhone'],
          cmop_division_phone: medication['cmopDivisionPhone'],
          prescription_source: medication['prescriptionSource'],
          disclaimer: medication['disclaimer'],
          provider_name: build_provider_name(medication),
          dial_cmop_division_phone: medication['dialCmopDivisionPhone'],
          indication_for_use: medication['indicationForUse'],
          remarks: medication['remarks'],
          disp_status: medication['dispStatus']
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

      def build_dispenses_information(medication)
        rf_records = medication.dig('rxRFRecords', 'rfRecord') || []
        return [] unless rf_records.is_a?(Array)

        rf_records.filter_map do |record|
          next unless record.is_a?(Hash)

          build_dispense_attributes(record)
        end
      end

      def build_dispense_attributes(record)
        {
          status: record['refillStatus'],
          dispensed_date: convert_to_iso8601(record['dispensedDate'], field_name: 'dispensed_date'),
          refill_date: convert_to_iso8601(record['refillDate'], field_name: 'refill_date'),
          facility_name: record['facilityApiName'].presence || record['facilityName'],
          instructions: record['sig'],
          quantity: record['quantity'],
          medication_name: record['prescriptionName'],
          id: record['id'],
          refill_submit_date: convert_to_iso8601(record['refillSubmitDate'], field_name: 'refill_submit_date'),
          prescription_number: record['prescriptionNumber'],
          cmop_division_phone: record['cmopDivisionPhone'],
          cmop_ndc_number: record['cmopNdcNumber'],
          remarks: record['remarks'],
          dial_cmop_division_phone: record['dialCmopDivisionPhone'],
          disclaimer: record['disclaimer']
        }
      end

      def convert_to_iso8601(date_string, field_name:)
        return nil if date_string.blank?

        Time.parse(date_string.to_s).utc.iso8601(3)
      rescue ArgumentError => e
        Rails.logger.warn("Failed to parse #{field_name} '#{date_string}': #{e.message}")
        date_string
      end

      def build_provider_name(medication)
        last_name = medication['providerLastName']
        first_name = medication['providerFirstName']

        return nil if last_name.blank? && first_name.blank?

        [last_name, first_name].compact.join(', ')
      end
    end
  end
end
