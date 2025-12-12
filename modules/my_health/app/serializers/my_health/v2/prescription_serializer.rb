# frozen_string_literal: true

module MyHealth
  module V2
    class PrescriptionSerializer
      # TODO: add V2 serializer specs

      include JSONAPI::Serializer

      set_id :prescription_id

      # TODO: Add links when show and trackings routes are implemented
      # link :self do |object|
      #   MyHealth::UrlHelper.new.v2_prescription_url(object.prescription_id)
      # end

      # link :tracking do |object|
      #   object.is_trackable ? MyHealth::UrlHelper.new.v2_prescription_trackings_url(object.prescription_id) : ''
      # end

      attribute :prescription_id, &:prescription_id
      attribute :prescription_number
      attribute :prescription_name

      attribute :prescription_image do |_object|
        nil
      end

      attribute :refill_status
      attribute :refill_submit_date
      attribute :refill_date
      attribute :refill_remaining
      attribute :facility_name
      attribute :ordered_date
      attribute :quantity
      attribute :expiration_date
      attribute :dispensed_date
      attribute :station_number
      attribute :is_refillable
      attribute :is_renewable
      attribute :is_trackable
    end
  end
end
