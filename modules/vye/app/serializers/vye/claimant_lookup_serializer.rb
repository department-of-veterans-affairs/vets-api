# frozen_string_literal: true

module Vye
  class ClaimantLookupSerializer < Vye::VyeSerializer
    def serializable_hash
      {
        claimant_id: @claimant_id
      }
    end
  end
end
