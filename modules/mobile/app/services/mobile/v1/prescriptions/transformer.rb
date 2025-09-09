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
            prescription_number: get_value(uhd_prescription, :prescription_number) || get_value(uhd_prescription, 'prescription_number'),
            prescription_name: get_value(uhd_prescription, :prescription_name) || get_value(uhd_prescription, 'prescription_name') || get_value(uhd_prescription, :medication_name) || get_value(uhd_prescription, 'medication_name'),
            refill_status: get_value(uhd_prescription, :refill_status) || get_value(uhd_prescription, 'refill_status') || get_value(uhd_prescription, :status) || get_value(uhd_prescription, 'status'),
            refill_submit_date: get_value(uhd_prescription, :refill_submit_date) || get_value(uhd_prescription, 'refill_submit_date'),
            refill_date: get_value(uhd_prescription, :refill_date) || get_value(uhd_prescription, 'refill_date') || get_value(uhd_prescription, :fill_date) || get_value(uhd_prescription, 'fill_date'),
            refill_remaining: get_value(uhd_prescription, :refill_remaining) || get_value(uhd_prescription, 'refill_remaining') || get_value(uhd_prescription, :refills_remaining) || get_value(uhd_prescription, 'refills_remaining'),
            facility_name: get_value(uhd_prescription, :facility_name) || get_value(uhd_prescription, 'facility_name') || get_value(uhd_prescription, :pharmacy_name) || get_value(uhd_prescription, 'pharmacy_name'),
            is_refillable: extract_boolean(uhd_prescription, [:refillable?, 'refillable?', :refillable, 'refillable']),
            is_trackable: extract_boolean(uhd_prescription, [:trackable?, 'trackable?', :trackable, 'trackable']),
            ordered_date: get_value(uhd_prescription, :ordered_date) || get_value(uhd_prescription, 'ordered_date'),
            quantity: get_value(uhd_prescription, :quantity) || get_value(uhd_prescription, 'quantity'),
            expiration_date: get_value(uhd_prescription, :expiration_date) || get_value(uhd_prescription, 'expiration_date'),
            prescribed_date: get_value(uhd_prescription, :prescribed_date) || get_value(uhd_prescription, 'prescribed_date'),
            station_number: get_value(uhd_prescription, :station_number) || get_value(uhd_prescription, 'station_number'),
            instructions: get_value(uhd_prescription, :sig) || get_value(uhd_prescription, 'sig') || get_value(uhd_prescription, :instructions) || get_value(uhd_prescription, 'instructions'),
            dispensed_date: get_value(uhd_prescription, :dispensed_date) || get_value(uhd_prescription, 'dispensed_date'),
            sig: get_value(uhd_prescription, :sig) || get_value(uhd_prescription, 'sig') || get_value(uhd_prescription, :instructions) || get_value(uhd_prescription, 'instructions'),
            ndc_number: get_value(uhd_prescription, :ndc_number) || get_value(uhd_prescription, 'ndc_number'),
            facility_phone_number: get_value(uhd_prescription, :cmop_division_phone) || get_value(uhd_prescription, 'cmop_division_phone') || get_value(uhd_prescription, :facility_phone_number) || get_value(uhd_prescription, 'facility_phone_number'),
            data_source_system: get_attributes_value(uhd_prescription, :data_source_system),
            prescription_source: 'UHD',
            tracking_info: build_tracking_info(uhd_prescription)
          )
        end

        def extract_prescription_id(uhd_prescription)
          id = get_value(uhd_prescription, :prescription_id) || get_value(uhd_prescription, 'prescription_id')
          return nil if id.nil?

          id.is_a?(String) ? id.to_i : id
        end

        def build_tracking_info(uhd_prescription)
          tracking_info = []

          # Handle case where UHD provides single tracking info
          tracking_number = get_value(uhd_prescription, :tracking_number) || get_value(uhd_prescription, 'tracking_number')
          shipper = get_value(uhd_prescription, :shipper) || get_value(uhd_prescription, 'shipper')
          
          if tracking_number.present? || shipper.present?
            tracking_info << {
              tracking_number: tracking_number,
              shipper: shipper
            }.compact
          end

          # Handle case where UHD provides array of tracking info
          uhd_tracking_info = get_value(uhd_prescription, :tracking_info) || get_value(uhd_prescription, 'tracking_info')
          if uhd_tracking_info.is_a?(Array)
            uhd_tracking_info.each do |tracking|
              tracking_info << {
                tracking_number: tracking[:tracking_number] || tracking['tracking_number'],
                shipper: tracking[:shipper] || tracking['shipper']
              }.compact
            end
          end

          tracking_info
        end

        # Helper method to get value from hash or object
        def get_value(object, key)
          if object.respond_to?(key)
            object.public_send(key)
          elsif object.respond_to?(:[])
            object[key]
          end
        end

        # Helper method to extract boolean values by trying multiple keys
        def extract_boolean(object, keys)
          keys.each do |key|
            value = get_value(object, key)
            return value unless value.nil?
          end
          false
        end

        # Helper method to get attributes value (for complex nested structures)
        def get_attributes_value(object, key)
          if object.respond_to?(:attributes) && object.attributes.respond_to?(key)
            object.attributes.public_send(key)
          elsif object.respond_to?(:attributes) && object.attributes.respond_to?(:[])
            object.attributes[key] || object.attributes[key.to_s]
          end
        end
      end
    end
  end
end