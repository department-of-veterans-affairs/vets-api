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

    ##
    # If we had a regular ID column, we could use `eager_encrypt` which would be
    # more performant:
    # https://github.com/ankane/kms_encrypted/blob/master/README.md?plain=1#L155
    #
    has_kms_key

    has_encrypted :reason, key: :kms_key, **lockbox_options

    validates :power_of_attorney_request, uniqueness: true
    validates :reason, absence: true, unless: -> { resolving.accepts_reasons? }

    # Enum for declination reasons
    enum declination_reason: {
      decline_health: 0,
      decline_address: 1,
      decline_health_address: 2,
      decline_VSO: 3,
      decline_other: 4
    }

    DECLINATION_REASON_TEXTS = {
      decline_health: 'Decline, because protected medical record access is limited',
      decline_address: 'Decline, because change of address isn\'t authorized',
      decline_health_address:
        'Decline, because change of address isn\'t authorized and protected medical record access is limited',
      decline_VSO: 'Decline, because the VSO isn\'t accepting new clients',
      decline_other: 'Decline, because of another reason'
    }.freeze

    def declination_reason_text
      DECLINATION_REASON_TEXTS[declination_reason&.to_sym]
    end

    class << self
      ##
      # Adding this public class method in addition to `create!` because this
      # implementation causes the uniqueness validation to be expressed.
      #
      def create_with_resolving!(resolving:, **attrs)
        transaction do
          resolving.save!
          create!(resolving:, **attrs)
        end
      end
    end
  end
end
