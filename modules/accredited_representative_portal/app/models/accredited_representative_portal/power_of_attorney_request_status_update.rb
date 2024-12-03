# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestStatusUpdate < ApplicationRecord
    delegated_type :status_updating, types: %w[
      PowerOfAttorneyRequestReplacements
      PowerOfAttorneyRequestExpirations
      PowerOfAttorneyRequestWithdrawals
      PowerOfAttorneyRequestDecisions
    ]

    module StatusUpdating
      extend ActiveSupport::Concern

      included do
        has_one(
          :power_of_attorney_request_status_update,
          as: :status_updating,
          touch: true
        )
      end
    end
  end
end
