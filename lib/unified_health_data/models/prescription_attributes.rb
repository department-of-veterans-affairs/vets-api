# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class PrescriptionAttributes
    include Vets::Model

    attribute :refill_status, String
    attribute :refill_submit_date, String
    attribute :refill_date, String
    attribute :refill_remaining, Integer
    attribute :facility_name, String
    attribute :ordered_date, String
    attribute :quantity, String
    attribute :expiration_date, String
    attribute :prescription_number, String
    attribute :prescription_name, String
    attribute :dispensed_date, String
    attribute :station_number, String
    attribute :is_refillable, Bool
    attribute :is_trackable, Bool
    attribute :instructions, String
  end
end
