# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequest < ApplicationRecord
    belongs_to :latest_status_update,
               class_name: 'PowerOfAttorneyRequestStatusUpdate',
               optional: true

    has_one :form,
            class_name: 'AccreditedRepresentativePortal::PowerOfAttorneyForm',
            foreign_key: :ar_power_of_attorney_request_id, # explicit foreign key
            inverse_of: :power_of_attorney_request,
            dependent: :destroy
  end
end
