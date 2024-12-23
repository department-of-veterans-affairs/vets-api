# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequest < ApplicationRecord
    module ClaimantTypes
      DEPENDENT = 'dependent'
      VETERAN = 'veteran'
    end

    belongs_to :claimant, class_name: 'UserAccount'

    has_one :power_of_attorney_form,
            class_name: 'AccreditedRepresentativePortal::PowerOfAttorneyForm',
            inverse_of: :power_of_attorney_request,
            required: true

    has_one :resolution,
            class_name: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution',
            inverse_of: :power_of_attorney_request

    before_validation :set_claimant_type

    private

    def set_claimant_type
      if power_of_attorney_form.parsed_data['dependent']
        self.claimant_type = ClaimantTypes::DEPENDENT
        return
      end

      if power_of_attorney_form.parsed_data['veteran']
        self.claimant_type = ClaimantTypes::VETERAN
        return
      end
    end
  end
end
