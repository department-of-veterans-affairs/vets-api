# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestDecision < ApplicationRecord
    include PowerOfAttorneyRequestResolution::Resolving

    self.inheritance_column = nil

    belongs_to :creator,
               class_name: 'UserAccount'

    validates :type, presence: true
  end
end
