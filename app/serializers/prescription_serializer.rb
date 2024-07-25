# frozen_string_literal: true

class PrescriptionSerializer
  include JSONAPI::Serializer
  singleton_class.include Rails.application.routes.url_helpers

  set_id :prescription_id
  set_type :prescriptions

  link :self do |object|
    v0_prescription_url(object.prescription_id)
  end

  link :tracking do |object|
    object.trackable? ? v0_prescription_trackings_url(object.prescription_id) : ''
  end

  attribute :prescription_id
  attribute :prescription_number
  attribute :prescription_name
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
  attribute :is_trackable
end
