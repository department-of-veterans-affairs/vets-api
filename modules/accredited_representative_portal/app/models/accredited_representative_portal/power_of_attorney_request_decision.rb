# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestDecision < ApplicationRecord
    self.inheritance_column = nil

    module Types
      ACCEPTANCE = 'AccreditedRepresentativePortal::PowerOfAttorneyRequestAcceptance'
      DECLINATION = 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDeclination'
    end

    belongs_to :creator,
               class_name: 'UserAccount'
  end
end
