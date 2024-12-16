# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestDecision < ApplicationRecord
    belongs_to :creator,
               class_name: 'UserAccount'

    has_one :power_of_attorney_request_resolution,
            as: :resolving,
            inverse_of: :resolving,
            dependent: :destroy

    validates :type, presence: true, length: { maximum: 255 }
  end
end
