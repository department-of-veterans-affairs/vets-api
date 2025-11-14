# frozen_string_literal: true

module MyHealth
  module V2
    class PrescriptionSerializer
      include JSONAPI::Serializer

      set_id :prescription_id

      # TODO: Add links when show and trackings routes are implemented
      # link :self do |object|
      #   MyHealth::UrlHelper.new.v2_prescription_url(object.prescription_id)
      # end

      # link :tracking do |object|
      #   object.is_trackable ? MyHealth::UrlHelper.new.v2_prescription_trackings_url(object.prescription_id) : ''
      # end

      attribute :prescription_id
      attribute :prescription_number
      attribute :prescription_name

      attribute :prescription_image do |object|
        object.prescription_image if object.respond_to?(:prescription_image)
      end

      attribute :refill_status
      attribute :refill_submit_date
      attribute :refill_date
      attribute :refill_remaining

      attribute :facility_name do |object|
        if object.respond_to?(:facility_api_name) && object.facility_api_name.present?
          object.facility_api_name
        else
          object.facility_name
        end
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
