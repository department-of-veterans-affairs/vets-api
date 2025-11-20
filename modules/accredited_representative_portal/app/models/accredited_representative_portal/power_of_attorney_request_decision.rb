# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestDecision < ApplicationRecord
    self.inheritance_column = nil
    include PowerOfAttorneyRequestResolution::Resolving

    enum :declination_reason, {
      HEALTH_RECORDS_WITHHELD: 0,
      ADDRESS_CHANGE_WITHHELD: 1,
      BOTH_WITHHELD: 2,
      NOT_ACCEPTING_CLIENTS: 3,
      LIMITED_AUTH: 4,
      OUTSIDE_SERVICE_TERRITORY: 5,
      OTHER: 6
    }

    DECLINATION_REASON_TEXTS = {
      HEALTH_RECORDS_WITHHELD: 'Decline, because protected medical record access is limited',
      ADDRESS_CHANGE_WITHHELD: 'Decline, because change of address isn\'t authorized',
      BOTH_WITHHELD:
        'Decline, because change of address isn\'t authorized and protected medical record access is limited',
      NOT_ACCEPTING_CLIENTS: 'Decline, because the VSO isn\'t accepting new clients',
      LIMITED_AUTH: 'Decline, because authorization is limited',
      OUTSIDE_SERVICE_TERRITORY: 'Decline, because the claimant is outside of the organization’s service territory',
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
    belongs_to :accredited_individual, class_name: 'Veteran::Service::Representative',
                                       foreign_key: :accredited_individual_registration_number,
                                       primary_key: :representative_id,
                                       optional: true,
                                       inverse_of: false

    validates :type, inclusion: { in: Types::ALL }

    class << self
      def create_acceptance!(
        creator_id:,
        power_of_attorney_holder_memberships:,
        power_of_attorney_request:,
        **attrs
      )
        create_with_resolution!(
          type: Types::ACCEPTANCE,
          creator_id:,
          power_of_attorney_holder_memberships:,
          power_of_attorney_request:,
          **attrs
        )
      end

      def create_declination!(
        creator_id:,
        power_of_attorney_holder_memberships:,
        power_of_attorney_request:,
        declination_reason:,
        **attrs
      )
        reason_key = declination_reason.to_s.gsub('DECLINATION_', '')

        create_with_resolution!(
          type: Types::DECLINATION,
          creator_id:,
          power_of_attorney_holder_memberships:,
          power_of_attorney_request:,
          declination_reason: reason_key,
          **attrs
        )
      end

      private

      def create_with_resolution!( # rubocop:disable Metrics/ParameterLists
        type:,
        creator_id:,
        power_of_attorney_holder_memberships:,
        power_of_attorney_request:,
        declination_reason: nil,
        **attrs
      )
        PowerOfAttorneyRequestResolution.transaction do
          poa_code = power_of_attorney_request.power_of_attorney_holder_poa_code
          membership = power_of_attorney_holder_memberships.find(poa_code)
          poa_holder = membership.power_of_attorney_holder

          decision = build_decision(
            creator_id:,
            type:,
            declination_reason:,
            power_of_attorney_holder_type: poa_holder.type,
            power_of_attorney_holder_poa_code: poa_holder.poa_code,
            accredited_individual_registration_number: membership.registration_number
          )

          create_resolution(decision:, power_of_attorney_request:, **attrs)

          decision
        end
      rescue => e
        log_error_and_raise(e)
      end

      def build_decision(**args)
        decision = new(**args.delete_if { |_, v| v.nil? })
        decision.save!
        decision
      end

      def create_resolution(decision:, power_of_attorney_request:, **attrs)
        PowerOfAttorneyRequestResolution.create!(
          power_of_attorney_request:,
          resolving: decision,
          **attrs
        )
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
