# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestExpiration < ApplicationRecord
    include PowerOfAttorneyRequestStatusUpdate::StatusUpdating
  end
end
