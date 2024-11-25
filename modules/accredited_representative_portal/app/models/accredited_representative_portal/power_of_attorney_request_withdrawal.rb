# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestWithdrawal < ApplicationRecord
    include PowerOfAttorneyRequestStatusUpdate::StatusUpdating
  end
end
