# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer
    class DecisionSerializer < ResolutionSerializer
      attribute(:type) { 'decision' }

      attribute :decision_type do |resolution|
        case resolution.resolving.type
        when PowerOfAttorneyRequestDecision::Types::ACCEPTANCE
          'acceptance'
        when PowerOfAttorneyRequestDecision::Types::DECLINATION
          'declination'
        end
      end

      attribute :reason, if: proc { |resolution|
        resolution.resolving.type == PowerOfAttorneyRequestDecision::Types::DECLINATION &&
          resolution.reason.present?
      }, &:reason

      attribute :declination_reason, if: proc { |resolution|
        resolution.resolving.type == PowerOfAttorneyRequestDecision::Types::DECLINATION
      } do |resolution|
        resolution.resolving.declination_reason
      end

      attribute :creator_id do |resolution|
        resolution.resolving.creator_id
      end

      attribute :accredited_individual do |resolution|
        resolution.resolving.accredited_individual&.then do |individual|
          AccreditedIndividualSerializer.new(individual).serializable_hash
        end
      end
    end
  end
end
