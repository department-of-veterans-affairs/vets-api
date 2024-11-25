# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestReplacement < ApplicationRecord
    include PowerOfAttorneyRequestStatusUpdate::StatusUpdating
  end
end
