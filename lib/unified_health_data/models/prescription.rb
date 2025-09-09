# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class Prescription
    include Vets::Model

    attribute :id, String
    attribute :type, String
    attribute :attributes, UnifiedHealthData::PrescriptionAttributes

    # Delegate methods to match Mobile::V0::PrescriptionsSerializer expectations
    def prescription_id
      id
    end

    def refill_status
      attributes&.refill_status
    end

    def refill_submit_date
      attributes&.refill_submit_date
    end

    def refill_date
      attributes&.refill_date
    end

    def refill_remaining
      attributes&.refill_remaining
    end

    def facility_name
      attributes&.facility_name
    end

    def ordered_date
      attributes&.ordered_date
    end

    def quantity
      attributes&.quantity
    end

    def expiration_date
      attributes&.expiration_date
    end

    def prescription_number
      attributes&.prescription_number
    end

    def prescription_name
      attributes&.prescription_name
    end

    def dispensed_date
      attributes&.dispensed_date
    end

    def station_number
      attributes&.station_number
    end

    def refillable?
      attributes&.is_refillable
    end

    def trackable?
      attributes&.is_trackable
    end

    def sig
      attributes&.instructions
    end

    def cmop_division_phone
      attributes&.facility_phone_number
    end

    def ndc_number
      attributes&.ndc_number
    end

    def prescribed_date
      attributes&.prescribed_date
    end

    def tracking_info
      attributes&.tracking_info || []
    end

    def tracking_number
      tracking_info&.first&.dig('tracking_number') || tracking_info&.first&.dig(:tracking_number)
    end

    def shipper
      tracking_info&.first&.dig('shipper') || tracking_info&.first&.dig(:shipper)
    end

    def prescription_source
      attributes&.prescription_source
    end

    def data_source_system
      attributes&.data_source_system
    end
  end
end
