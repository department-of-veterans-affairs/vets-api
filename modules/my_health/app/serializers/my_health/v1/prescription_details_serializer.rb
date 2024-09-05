# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionDetailsSerializer < PrescriptionSerializer
      include JSONAPI::Serializer

      set_id :prescription_id

      attribute :cmop_ndc_number
      attribute :in_cerner_transition
      attribute :not_refillable_display_message
      attribute :sig
      attribute :cmop_division_phone
      attribute :user_id
      attribute :provider_first_name
      attribute :provider_last_name
      attribute :remarks
      attribute :division_name
      attribute :modified_date
      attribute :institution_id
      attribute :dial_cmop_division_phone
      attribute :disp_status
      attribute :ndc
      attribute :reason
      attribute :prescription_number_index
      attribute :prescription_source
      attribute :disclaimer
      attribute :indication_for_use
      attribute :indication_for_use_flag
      attribute :category
      attribute :tracking_list do |object|
        next [] unless object.tracking_list

        tracking_list = object.tracking_list
        tracking_list.dig(0, 1) || []
      end
      attribute :rx_rf_records do |object|
        next [] unless object.rx_rf_records

        records = object.rx_rf_records
        records.dig(0, 1) || []
      end
      attribute :tracking
      attribute :orderable_item
      attribute :sorted_dispensed_date
      attribute :shape
      attribute :color
      attribute :back_imprint
      attribute :front_imprint
    end
  end
end
