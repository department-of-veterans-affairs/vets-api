# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequest < ApplicationRecord
    belongs_to :claimant, class_name: 'UserAccount'

    has_one :power_of_attorney_form,
            class_name: 'AccreditedRepresentativePortal::PowerOfAttorneyForm',
            inverse_of: :power_of_attorney_request

    has_one :resolution,
            class_name: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution',
            inverse_of: :power_of_attorney_request

    def self.policy_class
      PowerOfAttorneyRequestPolicy
    end
  end
end
