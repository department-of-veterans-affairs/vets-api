# frozen_string_literal: true

module Mobile
  module V1
    module Prescriptions
      class Transformer
        def transform(uhd_prescriptions)
          return [] if uhd_prescriptions.blank?

          uhd_prescriptions.map do |uhd_prescription|
            transform_prescription(uhd_prescription)
          end.compact
        end

        private

        def transform_prescription(uhd_prescription)
          # Convert UHD prescription to OpenStruct for dot notation access
          # while maintaining compatibility with mobile v0 serializer expectations
          OpenStruct.new(
            prescription_id: uhd_prescription.prescription_id,
            refill_status: uhd_prescription.refill_status,
            refill_submit_date: uhd_prescription.refill_submit_date,
            refill_date: uhd_prescription.refill_date,
            refill_remaining: uhd_prescription.refill_remaining,
            facility_name: uhd_prescription.facility_name,
            ordered_date: uhd_prescription.ordered_date,
            quantity: uhd_prescription.quantity,
            expiration_date: uhd_prescription.expiration_date,
            prescription_number: uhd_prescription.prescription_number,
            prescription_name: uhd_prescription.prescription_name,
            dispensed_date: uhd_prescription.dispensed_date,
            station_number: uhd_prescription.station_number,
            is_refillable: uhd_prescription.refillable?,
            is_trackable: uhd_prescription.trackable?,
            instructions: uhd_prescription.sig,
            facility_phone_number: uhd_prescription.cmop_division_phone,
            data_source_system: uhd_prescription.attributes&.data_source_system
          )
        end
      end
    end
  end
end