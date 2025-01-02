# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequest < ApplicationRecord
    module ClaimantTypes
      ALL = [
        DEPENDENT = 'dependent',
        VETERAN = 'veteran'
      ].freeze
    end

    belongs_to :claimant, class_name: 'UserAccount'

    has_one :power_of_attorney_form,
            inverse_of: :power_of_attorney_request,
            required: true

    has_one :resolution,
            class_name: 'PowerOfAttorneyRequestResolution',
            inverse_of: :power_of_attorney_request

    belongs_to :power_of_attorney_holder,
               inverse_of: :power_of_attorney_requests,
               polymorphic: true

    belongs_to :accredited_individual

    before_validation :set_claimant_type

    validates :claimant_type, inclusion: { in: ClaimantTypes::ALL }

    scope :with_status, lambda { |status|
      case status
      when 'Pending'
        where.missing(:resolution)

      when 'Accepted'
        # rubocop:disable Layout/LineLength
        left_joins(:resolution)
          .joins("LEFT OUTER JOIN ar_power_of_attorney_request_decisions AS decision ON decision.id = resolution.resolving_id AND resolution.resolving_type = 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision'")
          .where(resolution: { resolving_type: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision' })
          .where(decision: { type: 'PowerOfAttorneyRequestAcceptance' })
        # rubocop:enable Layout/LineLength
      when 'Declined'
        # rubocop:disable Layout/LineLength
        left_joins(:resolution)
          .joins("LEFT OUTER JOIN ar_power_of_attorney_request_decisions AS decision ON decision.id = resolution.resolving_id AND resolution.resolving_type = 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision'")
          .where(resolution: { resolving_type: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision' })
          .where(decision: { type: 'PowerOfAttorneyRequestDeclination' })
        # rubocop:enable Layout/LineLength
      else
        all
      end
    }

    scope :sorted_by, lambda { |field, direction|
      order(field => (direction == 'asc' ? :asc : :desc))
    }

    private

    def set_claimant_type
      if power_of_attorney_form.parsed_data['dependent']
        self.claimant_type = ClaimantTypes::DEPENDENT
        return
      end

      if power_of_attorney_form.parsed_data['veteran']
        self.claimant_type = ClaimantTypes::VETERAN
        nil
      end
    end
  end
end
