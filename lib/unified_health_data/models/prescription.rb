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
  end
end
