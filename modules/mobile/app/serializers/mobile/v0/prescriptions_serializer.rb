# frozen_string_literal: true

module Mobile
  module V0
    class PrescriptionsSerializer
      include JSONAPI::Serializer

      set_type :Prescription
      set_id :prescription_id
      attributes :refill_status,
                 :refill_submit_date,
                 :refill_date,
                 :refill_remaining,
                 :facility_name,
                 :ordered_date,
                 :expiration_date,
                 :prescription_number,
                 :prescription_name,
                 :dispensed_date,
                 :station_number,
                 :is_refillable,
                 :is_trackable

      attribute :quantity do |object|
        quantity = object.quantity
        quantity == quantity.to_i ? quantity.to_i : quantity
      end
      attribute :instructions, &:sig
      attribute :facility_phone_number, &:cmop_division_phone
    end
  end
end
