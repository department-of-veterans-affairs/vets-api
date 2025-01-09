# frozen_string_literal: true

module Vye
  class VyeSerializer
    attr_reader :resource

    def initialize(resource)
      @resource = resource
    end

    def to_json(*)
      Oj.dump(serializable_hash, mode: :compat, time_format: :ruby)
    end

    def status
      @resource&.status
    end
  end

  class ClaimantLookupSerializer < VyeSerializer
    def serializable_hash
      {
        claimant_id: @resource&.claimant_id
      }
    end
  end

  class ClaimantVerificationSerializer < VyeSerializer
    def serializable_hash
      {
        claimant_id: @resource&.claimant_id,
        delimiting_date: @resource&.delimiting_date,
        enrollment_verifications: @resource&.enrollment_verifications,
        verified_details: @resource&.verified_details,
        payment_on_hold: @resource&.payment_on_hold
      }
    end
  end

  class VerifyClaimantSerializer < VyeSerializer
    def serializable_hash
      {
        claimant_id: @resource&.claimant_id,
        delimiting_date: @resource&.delimiting_date,
        verified_details: @resource&.verified_details,
        payment_on_hold: @resource&.payment_on_hold
      }
    end
  end
end
