# frozen_string_literal: true

require 'unified_health_data/models/prescription'

module UnifiedHealthData
  module Serializers
    class PrescriptionSerializer
      include JSONAPI::Serializer

      set_type :Prescription
      set_id :prescription_id

      # Core prescription attributes
      attributes :refill_status,
                 :refill_submit_date,
                 :refill_date,
                 :refill_remaining,
                 :facility_name,
                 :ordered_date,
                 :quantity,
                 :expiration_date,
                 :prescription_number,
                 :prescription_name,
                 :dispensed_date,
                 :station_number,
                 :is_refillable,
                 :is_trackable,
                 :prescription_source,
                 :instructions,
                 :facility_phone_number
    end
  end
end
