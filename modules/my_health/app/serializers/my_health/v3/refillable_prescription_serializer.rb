# frozen_string_literal: true

module MyHealth
  module V3
    # Minimal serializer for refillable prescriptions widget/modal
    # Only includes essential fields needed for prescription selection UI
    class RefillablePrescriptionSerializer
      include JSONAPI::Serializer

      set_id :prescription_id
      set_type :refillable_prescription

      # Essential fields for refill selection
      attribute :prescription_name
      attribute :prescription_number
      attribute :refill_remaining
      attribute :expiration_date
      attribute :station_number
      attribute :is_refillable
      attribute :disp_status
    end
  end
end
