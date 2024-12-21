# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer
    include JSONAPI::Serializer

    attributes :claimant_id, :created_at

    has_one :resolution, if: :resolution.to_proc, serializer: proc { |resolution|
      case resolution.resolving
      when PowerOfAttorneyRequestDecision
        PowerOfAttorneyRequestDecisionSerializer
      when PowerOfAttorneyRequestExpiration
        PowerOfAttorneyRequestExpirationSerializer
      end
    }
  end
end
