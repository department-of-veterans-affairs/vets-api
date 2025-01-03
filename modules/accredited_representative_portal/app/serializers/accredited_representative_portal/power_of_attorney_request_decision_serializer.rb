# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestDecisionSerializer < PowerOfAttorneyRequestResolutionSerializer
    attribute :decision_type do |resolution|
      case resolution.resolving.type
      when PowerOfAttorneyRequestDecision::Types::ACCEPTANCE
        'acceptance'
      when PowerOfAttorneyRequestDecision::Types::DECLINATION
        'declination'
      end
    end

    attribute :reason, if: proc { |resolution|
      resolution.resolving.type == PowerOfAttorneyRequestDecision::Types::DECLINATION
    }

    attribute :creator_id do |resolution|
      resolution.resolving.creator_id
    end
  end
end
