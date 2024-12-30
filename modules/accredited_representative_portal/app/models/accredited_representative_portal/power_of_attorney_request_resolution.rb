# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestResolution < ApplicationRecord
    belongs_to :power_of_attorney_request,
               class_name: 'AccreditedRepresentativePortal::PowerOfAttorneyRequest',
               inverse_of: :resolution

    RESOLVING_TYPES = [
      'AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration',
      'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision'
    ].freeze

    delegated_type :resolving, types: RESOLVING_TYPES

    validates :power_of_attorney_request, uniqueness: true

    has_kms_key

    has_encrypted :reason, key: :kms_key, **lockbox_options
  end
end
