# frozen_string_literal: true

module MyHealth
  module V1
    class TrackingSerializer
      include JSONAPI::Serializer

      set_id :tracking_number
      set_type :trackings

      link :self do |object|
        MyHealth::UrlHelper.new.v1_prescription_trackings_url(object.prescription_id)
      end

      link :prescription do |object|
        MyHealth::UrlHelper.new.v1_prescription_url(object.prescription_id)
      end

      link :tracking_url do |object|
        case object.delivery_service.upcase
        when 'UPS'
          "https://wwwapps.ups.com/WebTracking/track?track=yes&trackNums=#{object.tracking_number}"
        when 'USPS'
          "https://tools.usps.com/go/TrackConfirmAction?tLabels=#{object.tracking_number}"
        else
          ''
        end
      end

      attribute :tracking_number
      attribute :prescription_id
      attribute :prescription_number
      attribute :prescription_name
      attribute :facility_name
      attribute :rx_info_phone_number
      attribute :ndc_number
      attribute :shipped_date
      attribute :delivery_service
      attribute :other_prescriptions
    end
  end
end
