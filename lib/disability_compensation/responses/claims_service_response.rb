# frozen_string_literal: true

module DisabilityCompensation
  module ApiProvider
    # Used in conjunction with the PPIU/Direct Deposit Provider
    class ClaimPhaseDates
      include ActiveModel::Serialization
      include Virtus.model

      attribute :phase_change_date, String
    end

    class Claim
      include ActiveModel::Serialization
      include Virtus.model

      attribute :id, String
      attribute :base_end_product_code, String
      attribute :development_letter_sent, Boolean
      attribute :status, String
      attribute :claim_phase_dates, ClaimPhaseDates
    end

    class ClaimsServiceResponse
      include ActiveModel::Serialization
      include Virtus.model

      attribute :open_claims, Array[DisabilityCompensation::ApiProvider::Claim]
    end
  end
end
