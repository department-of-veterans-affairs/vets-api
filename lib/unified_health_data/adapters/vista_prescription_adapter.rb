# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    class VistaPrescriptionAdapter
      def parse(medication)
        return nil if medication.nil? || medication['prescriptionId'].nil?

        attributes = build_prescription_attributes(medication)
        UnifiedHealthData::Prescription.new({
                                              id: medication['prescriptionId'].to_s,
                                              type: 'Prescription',
                                              attributes:
                                            })
      rescue => e
        Rails.logger.error("Error parsing VistA prescription: #{e.message}")
        nil
      end

      private

      # rubocop:disable Metrics/MethodLength
      def build_prescription_attributes(medication)
        UnifiedHealthData::PrescriptionAttributes.new({
                                                        refill_status: medication['refillStatus'],
                                                        refill_submit_date: medication['refillSubmitDate'],
                                                        refill_date: medication['refillDate'],
                                                        refill_remaining: medication['refillRemaining'],
                                                        facility_name: medication['facilityName'],
                                                        ordered_date: medication['orderedDate'],
                                                        quantity: medication['quantity'],
                                                        expiration_date: medication['expirationDate'],
                                                        prescription_number:
                                                          medication['prescriptionNumber'],
                                                        prescription_name: medication['prescriptionName'],
                                                        dispensed_date: medication['dispensedDate'],
                                                        station_number: medication['stationNumber'],
                                                        is_refillable: medication['isRefillable'],
                                                        is_trackable: medication['isTrackable'],
                                                        instructions: medication['sig'],
                                                        facility_phone_number:
                                                          medication['cmopDivisionPhone'],
                                                        data_source_system:
                                                          medication['dataSourceSystem'] || 'VISTA',
                                                        ndc_number: medication['ndcNumber'],
                                                        prescribed_date: medication['prescribedDate'],
                                                        tracking_info: build_tracking_info(medication),
                                                        prescription_source: 'VISTA'
                                                      })
      end
      # rubocop:enable Metrics/MethodLength

      def build_tracking_info(medication)
        tracking_info = []

        # Handle single tracking info from Vista
        if medication['trackingNumber'].present? || medication['shipper'].present?
          tracking_info << {
            'tracking_number' => medication['trackingNumber'],
            'shipper' => medication['shipper']
          }.compact
        end

        # Handle array of tracking info if Vista provides it
        if medication['trackingInfo'].is_a?(Array)
          medication['trackingInfo'].each do |tracking|
            tracking_info << {
              'tracking_number' => tracking['trackingNumber'] || tracking['tracking_number'],
              'shipper' => tracking['shipper']
            }.compact
          end
        end

        tracking_info
      end
    end
  end
end
