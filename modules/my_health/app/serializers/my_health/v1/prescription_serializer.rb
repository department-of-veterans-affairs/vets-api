# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionSerializer
      include JSONAPI::Serializer

      set_id :prescription_id

      link :self do |object|
        MyHealth::UrlHelper.new.v1_prescription_url(object.prescription_id)
      end

      link :tracking do |object|
        object.trackable? ? MyHealth::UrlHelper.new.v1_prescription_trackings_url(object.prescription_id) : ''
      end

      attribute :prescription_id
      attribute :prescription_number
      attribute :prescription_name
      attribute :prescription_image
      attribute :refill_status
      attribute :refill_submit_date
      attribute :refill_date
      attribute :refill_remaining

      attribute :facility_name do |object|
        object.facility_api_name.presence || object.facility_name
      end

      attribute :ordered_date
      attribute :quantity
      attribute :expiration_date
      attribute :dispensed_date
      attribute :station_number
      attribute :is_refillable
      attribute :is_trackable
    end
  end
end
