# frozen_string_literal: true

require 'vets/model'

module DisabilityCompensation
  module ApiProvider
    # Used in conjunction with the PPIU/Direct Deposit Provider
    class ClaimPhaseDates
      include Vets::Model

      attribute :phase_change_date, String
    end

    class Claim
      include Vets::Model

      attribute :id, String
      attribute :base_end_product_code, String
      attribute :development_letter_sent, Bool
      attribute :status, String
      attribute :claim_date, String
      attribute :claim_phase_dates, ClaimPhaseDates
    end

    class ClaimsServiceResponse
      include Vets::Model

      attribute :open_claims, DisabilityCompensation::ApiProvider::Claim, array: true
    end
  end
end
