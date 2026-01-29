# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class Prescription
    include Vets::Model

    attribute :id, String
    attribute :prescription_id, String
    attribute :type, String
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
    attribute :is_renewable, Bool
    attribute :is_trackable, Bool
    attribute :tracking, Array, default: []
    attribute :instructions, String
    attribute :facility_phone_number, String
    attribute :cmop_division_phone, String
    attribute :dial_cmop_division_phone, String
    attribute :prescription_source, String
    attribute :category, Array, default: []
    attribute :dispenses, Array, default: []
    attribute :disclaimer, String
    attribute :provider_name, String
    attribute :indication_for_use, String
    attribute :remarks, String
    attribute :cmop_ndc_number, String
    attribute :grouped_medications, Array, default: nil
    attribute :disp_status, String
  end
end
