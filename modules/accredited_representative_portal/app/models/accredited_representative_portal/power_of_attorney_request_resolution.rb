# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestResolution < ApplicationRecord
    belongs_to :power_of_attorney_request,
               class_name: 'PowerOfAttorneyRequest',
               inverse_of: :resolution

    RESOLVING_TYPES = %w[
      PowerOfAttorneyRequestExpiration
      PowerOfAttorneyRequestDecision
      PowerOfAttorneyRequestWithdrawal
    ].freeze

    delegated_type :resolving,
                   types: RESOLVING_TYPES,
                   inverse_of: :resolution

    module Resolving
      extend ActiveSupport::Concern

      included do
        has_one :resolution,
                as: :resolving,
                inverse_of: :resolving,
                class_name: 'PowerOfAttorneyRequestResolution'
      end

      def accepts_reasons?
        false
      end
    end

    has_kms_key
    has_encrypted :reason, key: :kms_key, **lockbox_options

    # Modify the error message for uniqueness validation
    validates :power_of_attorney_request, uniqueness: { 
      message: 'has already been taken' 
    }
    validates :reason, absence: true, unless: -> { resolving.accepts_reasons? }

    class << self
      def create_with_resolving!(resolving:, **attrs)
        transaction do
          resolving.save!
          create!(resolving:, **attrs)
        end
      end
    end
  end
end
