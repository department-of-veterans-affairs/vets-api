# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V1
    class TransformedPrescription < Common::Resource
      attribute :prescription_id, Types::Integer
      attribute :prescription_number, Types::String.optional
      attribute :prescription_name, Types::String.optional
      attribute :refill_status, Types::String.optional
      attribute :refill_submit_date, Types::DateTime.optional
      attribute :refill_date, Types::DateTime.optional
      attribute :refill_remaining, Types::Integer.optional
      attribute :facility_name, Types::String.optional
      attribute :is_refillable, Types::Bool.optional.default(false)
      attribute :is_trackable, Types::Bool.optional.default(false)
      attribute :ordered_date, Types::DateTime.optional
      attribute :quantity, Types::Integer.optional
      attribute :expiration_date, Types::DateTime.optional
      attribute :prescribed_date, Types::DateTime.optional
      attribute :station_number, Types::String.optional
      attribute :instructions, Types::String.optional
      attribute :dispensed_date, Types::DateTime.optional
      attribute :sig, Types::String.optional
      attribute :ndc_number, Types::String.optional
      attribute :facility_phone_number, Types::String.optional
      attribute :data_source_system, Types::String.optional
      attribute :prescription_source, Types::String.optional.default('UHD')

      # Ensure compatibility with existing serializer expectations
      alias_method :cmop_division_phone, :facility_phone_number
      alias_method :cmop_ndc_number, :ndc_number
    end
  end
end
