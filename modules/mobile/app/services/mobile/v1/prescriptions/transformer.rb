# frozen_string_literal: true

require_relative '../../models/mobile/v1/transformed_prescription'

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
          # Convert UHD prescription to proper model object
          # maintaining compatibility with mobile v0 serializer expectations
          Mobile::V1::TransformedPrescription.new(
            prescription_id: extract_prescription_id(uhd_prescription),
            prescription_number: uhd_prescription.prescription_number,
            prescription_name: uhd_prescription.prescription_name,
            refill_status: uhd_prescription.refill_status,
            refill_submit_date: parse_date(uhd_prescription.refill_submit_date),
            refill_date: parse_date(uhd_prescription.refill_date),
            refill_remaining: uhd_prescription.refill_remaining,
            facility_name: uhd_prescription.facility_name,
            is_refillable: uhd_prescription.refillable?,
            is_trackable: uhd_prescription.trackable?,
            ordered_date: parse_date(uhd_prescription.ordered_date),
            quantity: uhd_prescription.quantity,
            expiration_date: parse_date(uhd_prescription.expiration_date),
            prescribed_date: parse_date(uhd_prescription.prescribed_date),
            station_number: uhd_prescription.station_number,
            instructions: uhd_prescription.sig,
            dispensed_date: parse_date(uhd_prescription.dispensed_date),
            sig: uhd_prescription.sig,
            ndc_number: uhd_prescription.ndc_number,
            facility_phone_number: uhd_prescription.cmop_division_phone,
            data_source_system: uhd_prescription.attributes&.data_source_system,
            prescription_source: 'UHD'
          )
        end

        def extract_prescription_id(uhd_prescription)
          id = uhd_prescription.prescription_id
          return nil if id.nil?

          id.is_a?(String) ? id.to_i : id
        end

        def parse_date(date_string)
          return nil if date_string.blank?

          # Handle various date formats that might come from UHD
          case date_string
          when String
            Time.zone.parse(date_string)
          when Time, DateTime
            date_string
          else
            nil
          end
        rescue ArgumentError
          nil
        end
      end
    end
  end
end