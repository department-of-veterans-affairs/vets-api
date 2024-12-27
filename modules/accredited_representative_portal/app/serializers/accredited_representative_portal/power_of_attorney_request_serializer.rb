# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer
    include JSONAPI::Serializer

    attributes :claimant_id, :created_at

    attribute :resolution do |poa_request|
      next unless poa_request.resolution

      serializer =
        case poa_request.resolution.resolving
        when PowerOfAttorneyRequestDecision
          PowerOfAttorneyRequestDecisionSerializer
        when PowerOfAttorneyRequestExpiration
          PowerOfAttorneyRequestExpirationSerializer
        end

      serializer.new(poa_request.resolution)
    end
  end
end
