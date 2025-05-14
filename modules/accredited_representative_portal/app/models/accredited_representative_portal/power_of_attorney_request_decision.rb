# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestDecision < ApplicationRecord
    self.inheritance_column = nil
    include PowerOfAttorneyRequestResolution::Resolving

    enum declination_reason: {
      HEALTH_RECORDS_WITHHELD: 0,
      ADDRESS_CHANGE_WITHHELD: 1,
      BOTH_WITHHELD: 2,
      NOT_ACCEPTING_CLIENTS: 3,
      OTHER: 4
    }

    DECLINATION_REASON_TEXTS = {
      HEALTH_RECORDS_WITHHELD: 'Decline, because protected medical record access is limited',
      ADDRESS_CHANGE_WITHHELD: 'Decline, because change of address isn\'t authorized',
      BOTH_WITHHELD:
        'Decline, because change of address isn\'t authorized and protected medical record access is limited',
      NOT_ACCEPTING_CLIENTS: 'Decline, because the VSO isn\'t accepting new clients',
      OTHER: 'Decline, because of another reason'
    }.freeze

    def declination_reason_text
      DECLINATION_REASON_TEXTS[declination_reason.to_sym]
    end

    validates :declination_reason, presence: true, if: -> { type == Types::DECLINATION }

    module Types
      ALL = [
        ACCEPTANCE = 'PowerOfAttorneyRequestAcceptance',
        DECLINATION = 'PowerOfAttorneyRequestDeclination'
      ].freeze
    end

    belongs_to :creator, class_name: 'UserAccount'

    validates :type, inclusion: { in: Types::ALL }

    class << self
      def create_acceptance!(creator:, power_of_attorney_request:, **attrs)
        Rails.logger.info("Creating acceptance with creator: #{creator.id}")
        create_with_resolution!(
          type: Types::ACCEPTANCE,
          creator:,
          power_of_attorney_request:,
          **attrs
        )
      end

      def create_declination!(creator:, power_of_attorney_request:, declination_reason:, **attrs)
        Rails.logger.info("Creating declination with creator: #{creator.id}, reason: #{declination_reason}")
        # Handle string vs symbol for declination reason
        reason_key = declination_reason.to_s.gsub('DECLINATION_', '')
        Rails.logger.info("Normalized reason key: #{reason_key}")

        create_with_resolution!(
          type: Types::DECLINATION,
          creator:,
          power_of_attorney_request:,
          declination_reason: reason_key,
          **attrs
        )
      end

      private

      def create_with_resolution!(creator:, type:, power_of_attorney_request:, declination_reason: nil, **attrs)
        Rails.logger.info("create_with_resolution called: type=#{type}, reason=#{declination_reason}")

        PowerOfAttorneyRequestResolution.transaction do
          decision = build_decision(creator:, type:, declination_reason:)
          create_resolution(decision:, power_of_attorney_request:, **attrs)
          decision
        end
      rescue => e
        log_error_and_raise(e)
      end

      def build_decision(creator:, type:, declination_reason:)
        decision = new(type:, creator:)

        if declination_reason.present?
          Rails.logger.info("Setting declination_reason: #{declination_reason}")
          decision.declination_reason = declination_reason
        end

        decision.save!
        Rails.logger.info("Decision saved with ID: #{decision.id}")
        decision
      end

      def create_resolution(decision:, power_of_attorney_request:, **attrs)
        resolution = PowerOfAttorneyRequestResolution.create!(
          power_of_attorney_request:,
          resolving: decision,
          **attrs
        )
        Rails.logger.info("Resolution created with ID: #{resolution.id}")
        resolution
      end

      def log_error_and_raise(error)
        Rails.logger.error("Error in create_with_resolution!: #{error.class} - #{error.message}")
        Rails.logger.error(error.backtrace.join("\n"))
        raise
      end
    end

    def accepts_reasons?
      type == Types::DECLINATION
    end
  end
end
