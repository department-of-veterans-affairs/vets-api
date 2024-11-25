# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestDecision < ApplicationRecord
    include PowerOfAttorneyRequestStatusUpdate::StatusUpdating

    self.inheritance_column = nil
  end
end
