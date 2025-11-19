# frozen_string_literal: true

module MyHealth
  module V2
    class PrescriptionDetailsSerializer < PrescriptionSerializer
      include JSONAPI::Serializer

      set_id :prescription_id

      # Fields not in UHD model - defensive
      attribute :cmop_ndc_number do |object|
        object.cmop_ndc_number if object.respond_to?(:cmop_ndc_number)
      end

      attribute :in_cerner_transition do |object|
        object.in_cerner_transition if object.respond_to?(:in_cerner_transition)
      end

      attribute :not_refillable_display_message do |object|
        object.not_refillable_display_message if object.respond_to?(:not_refillable_display_message)
      end

      # UHD uses 'instructions' field, alias as 'sig'
      attribute :sig, &:instructions

      # UHD uses 'facility_phone_number' field, alias as 'cmop_division_phone'
      attribute :cmop_division_phone, &:facility_phone_number

      attribute :user_id do |object|
        object.user_id if object.respond_to?(:user_id)
      end

      attribute :provider_first_name do |_object|
        nil
      end

      attribute :provider_last_name do |object|
        object.provider_name if object.respond_to?(:provider_name)
      end

      attribute :remarks

      attribute :division_name do |object|
        object.division_name if object.respond_to?(:division_name)
      end

      attribute :modified_date do |object|
        object.modified_date if object.respond_to?(:modified_date)
      end

      attribute :institution_id do |object|
        object.institution_id if object.respond_to?(:institution_id)
      end

      attribute :dial_cmop_division_phone do |object|
        object.dial_cmop_division_phone if object.respond_to?(:dial_cmop_division_phone)
      end

      attribute :pharmacy_phone_number do |object|
        object.pharmacy_phone_number if object.respond_to?(:pharmacy_phone_number)
      end

      attribute :disp_status

      attribute :ndc do |object|
        object.ndc if object.respond_to?(:ndc)
      end

      attribute :reason do |object|
        object.reason if object.respond_to?(:reason)
      end

      attribute :prescription_number_index do |object|
        object.prescription_number_index if object.respond_to?(:prescription_number_index)
      end

      attribute :prescription_source

      attribute :disclaimer

      attribute :indication_for_use

      attribute :indication_for_use_flag do |object|
        object.indication_for_use_flag if object.respond_to?(:indication_for_use_flag)
      end

      attribute :category

      # UHD has 'tracking' array field, alias as 'tracking_list'
      attribute :tracking_list, &:tracking

      # UHD has 'dispenses' array field, alias as 'rx_rf_records'
      attribute :rx_rf_records do |object|
        if object.respond_to?(:dispenses) && object.dispenses.present?
          object.dispenses
        else
          []
        end
      end

      # UHD has 'tracking' as Array, convert to boolean for this attribute
      attribute :tracking do |object|
        !object.tracking.empty?
      end

      attribute :orderable_item do |object|
        object.orderable_item if object.respond_to?(:orderable_item)
      end

      attribute :sorted_dispensed_date do |object|
        object.sorted_dispensed_date if object.respond_to?(:sorted_dispensed_date)
      end

      attribute(:shape) { nil }
      attribute(:color) { nil }
      attribute(:back_imprint) { nil }
      attribute(:front_imprint) { nil }

      attribute :grouped_medications, &:grouped_medications
    end
  end
end
