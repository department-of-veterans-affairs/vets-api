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

    delegated_type :resolving, types: RESOLVING_TYPES, dependent: :destroy, optional: true

    has_kms_key

    has_encrypted :reason, key: :kms_key, **lockbox_options

    # Validations
    validates :power_of_attorney_request_id, uniqueness: true
    validates :resolving_type, presence: true, inclusion: { in: RESOLVING_TYPES, allow_nil: true }
    validates :resolving_id, presence: true, if: -> { resolving_type.present? }
    validates :created_at, presence: true
  end
end
