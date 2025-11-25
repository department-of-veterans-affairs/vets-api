# frozen_string_literal: true

require 'unified_health_data/models/prescription'

module UnifiedHealthData
  module Serializers
    class PrescriptionSerializer
      include JSONAPI::Serializer

      # Core prescription attributes
      attributes :type,
                 :refill_status,
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
                 :tracking,
                 :prescription_source,
                 :instructions,
                 :facility_phone_number,
                 :cmop_division_phone,
                 :cmop_ndc_number,
                 :remarks,
                 :disp_status
    end
  end
end
