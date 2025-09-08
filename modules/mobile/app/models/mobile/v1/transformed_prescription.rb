# frozen_string_literal: true

require 'vets/model'

module Mobile
  module V1
    class TransformedPrescription
      include Vets::Model

      attribute :prescription_id, Integer
      attribute :prescription_number, String
      attribute :prescription_name, String
      attribute :refill_status, String
      attribute :refill_submit_date, Vets::Type::UTCTime
      attribute :refill_date, Vets::Type::UTCTime
      attribute :refill_remaining, Integer
      attribute :facility_name, String
      attribute :is_refillable, Bool
      attribute :is_trackable, Bool
      attribute :ordered_date, Vets::Type::UTCTime
      attribute :quantity, Integer
      attribute :expiration_date, Vets::Type::UTCTime
      attribute :prescribed_date, Vets::Type::UTCTime
      attribute :station_number, String
      attribute :instructions, String
      attribute :dispensed_date, Vets::Type::UTCTime
      attribute :sig, String
      attribute :ndc_number, String
      attribute :facility_phone_number, String
      attribute :data_source_system, String
      attribute :prescription_source, String

      # Ensure compatibility with existing serializer expectations
      alias_method :cmop_division_phone, :facility_phone_number
      alias_method :cmop_ndc_number, :ndc_number
    end
  end
end
