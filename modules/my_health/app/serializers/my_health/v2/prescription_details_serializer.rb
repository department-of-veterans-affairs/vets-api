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

      attribute :provider_first_name do |object|
        object.provider_first_name if object.respond_to?(:provider_first_name)
      end

      attribute :provider_last_name do |object|
        object.provider_last_name if object.respond_to?(:provider_last_name)
      end

      attribute :remarks do |object|
        object.remarks if object.respond_to?(:remarks)
      end

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

      attribute :disp_status do |object|
        object.disp_status if object.respond_to?(:disp_status)
      end

      attribute :ndc do |object|
        object.ndc if object.respond_to?(:ndc)
      end

      attribute :reason do |object|
        object.reason if object.respond_to?(:reason)
      end

      attribute :prescription_number_index do |object|
        object.prescription_number_index if object.respond_to?(:prescription_number_index)
      end

      # UHD has this field
      attribute :prescription_source

      attribute :disclaimer do |object|
        object.disclaimer if object.respond_to?(:disclaimer)
      end

      attribute :indication_for_use do |object|
        object.indication_for_use if object.respond_to?(:indication_for_use)
      end

      attribute :indication_for_use_flag do |object|
        object.indication_for_use_flag if object.respond_to?(:indication_for_use_flag)
      end

      # UHD has this field (Array)
      attribute :category

      # UHD has 'tracking' array field, alias as 'tracking_list'
      attribute :tracking_list, &:tracking

      attribute :rx_rf_records do |object|
        object.rx_rf_records if object.respond_to?(:rx_rf_records)
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

      attribute :shape do |object|
        object.shape if object.respond_to?(:shape)
      end

      attribute :color do |object|
        object.color if object.respond_to?(:color)
      end

      attribute :back_imprint do |object|
        object.back_imprint if object.respond_to?(:back_imprint)
      end

      attribute :front_imprint do |object|
        object.front_imprint if object.respond_to?(:front_imprint)
      end

      attribute :grouped_medications do |object|
        if object.respond_to?(:grouped_medications)
          object.grouped_medications
        elsif object.instance_variable_defined?(:@grouped_medications)
          object.instance_variable_get(:@grouped_medications)
        end
      end
    end
  end
end
