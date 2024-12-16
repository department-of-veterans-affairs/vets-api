# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequest < ApplicationRecord
    belongs_to :claimant,
               class_name: 'UserAccount'

    has_one :form,
            class_name: 'AccreditedRepresentativePortal::PowerOfAttorneyForm',
            inverse_of: :power_of_attorney_request,
            dependent: :destroy

    has_one :resolution,
            class_name: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution',
            inverse_of: :power_of_attorney_request,
            dependent: :destroy

    # Validations
    validates :created_at, presence: true
  end
end
