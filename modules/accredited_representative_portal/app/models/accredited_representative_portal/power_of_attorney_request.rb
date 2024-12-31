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
            validate: true,
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
