# frozen_string_literal: true
class TrackingSerializer < ActiveModel::Serializer
  def id
    object.tracking_number
  end

  link(:self) { rx_v1_prescription_trackings_url(object.prescription_id) }
  link(:prescription) { rx_v1_prescription_url(object.prescription_id) }
  link(:tracking_url) do
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
end
