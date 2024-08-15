# frozen_string_literal: true

class TrackingSerializer
  include JSONAPI::Serializer
  singleton_class.include Rails.application.routes.url_helpers

  set_id :tracking_number
  set_type :trackings

  link :self do |object|
    v0_prescription_trackings_url(object.prescription_id)
  end

  link :prescription do |object|
    v0_prescription_url(object.prescription_id)
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
