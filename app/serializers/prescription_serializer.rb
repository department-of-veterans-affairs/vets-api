# frozen_string_literal: true
class PrescriptionSerializer < ActiveModel::Serializer
  def id
    object.prescription_id
  end

  link(:self) { v0_prescription_url(object.prescription_id) }
  link(:tracking) { v0_prescription_trackings_url(object.prescription_id) if object.trackable? }

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
