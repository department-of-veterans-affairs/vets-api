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
                                                        instructions: medication['sig']
                                                      })
      end
    end
  end
end
