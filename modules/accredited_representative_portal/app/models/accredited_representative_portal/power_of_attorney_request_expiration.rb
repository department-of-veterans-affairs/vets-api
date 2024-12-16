# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestExpiration < ApplicationRecord
    has_one :power_of_attorney_request_resolution,
            as: :resolving,
            inverse_of: :resolving,
            dependent: :destroy

    # Validations
    validates :id, presence: true
  end
end
