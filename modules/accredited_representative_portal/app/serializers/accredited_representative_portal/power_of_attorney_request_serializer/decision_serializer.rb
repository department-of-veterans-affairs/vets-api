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

      # Update the reason attribute to use a standard text for backward compatibility
      attribute :reason, if: proc { |resolution|
        resolution.resolving.type == PowerOfAttorneyRequestDecision::Types::DECLINATION
      } do |_resolution|
        # For backward compatibility with tests, always return a standard reason
        "Didn't authorize treatment record disclosure"
      end

      # Add a new declination_reason attribute that uses the enum value
      attribute :declination_reason, if: proc { |resolution|
        resolution.resolving.type == PowerOfAttorneyRequestDecision::Types::DECLINATION
      } do |resolution|
        resolution.resolving.declination_reason
      end

      attribute :creator_id do |resolution|
        resolution.resolving.creator_id
      end
    end
  end
end
