# frozen_string_literal: true

require 'vets/model'
# Tracking Model
class Tracking
  include Vets::Model

  attribute :prescription_id, Integer
  attribute :prescription_name, String
  attribute :prescription_number, String
  attribute :facility_name, String
  attribute :rx_info_phone_number, String
  attribute :ndc_number, String
  attribute :shipped_date, Vets::Type::UTCTime
  attribute :delivery_service, String
  attribute :tracking_number, String
  attribute :other_prescriptions, Hash, array: true

  default_sort_by shipped_date: :desc
end
