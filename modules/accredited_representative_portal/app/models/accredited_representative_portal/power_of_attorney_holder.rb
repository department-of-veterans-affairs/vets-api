# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyHolder <
    Data.define(
      :type,
      :poa_code,
      :can_accept_digital_poa_requests
    )

    module Types
      ALL = [
        ##
        # Future types:
        # ```
        # ATTORNEY = 'attorney',
        # CLAIMS_AGENT = 'claims_agent',
        # ```
        #
        VETERAN_SERVICE_ORGANIZATION = 'veteran_service_organization'
      ].freeze
    end

    PREFIX = "#{name.demodulize.underscore}_".freeze
    PRIMARY_KEY_ATTRIBUTE_NAMES = %i[
      power_of_attorney_holder_type
      power_of_attorney_holder_poa_code
    ].freeze

    class << self
      ##
      # Lookup power of attorney holder memberships by email:
      # - User has many registrations
      # - Registration has many power of attorney holders
      #   - But only really for a VSO-type registration
      #   - Else has one
      #
      def for_user(email:, icn:)
        registrations = UserAccountAccreditedIndividual.for_user(email:, icn:)
        registrations.flat_map(&method(:for_registration))
      end

      private

      def for_registration(registration)
        number = registration.accredited_individual_registration_number
        type = registration.power_of_attorney_holder_type

        case type
        when Types::VETERAN_SERVICE_ORGANIZATION
          ##
          # Other types are 1:1 and will have no reason to introduce a
          # complicated method that takes a block like this.
          #
          get_organizations(number) { |attrs| new(type:, **attrs) }
        else
          []
        end
      end

      def get_organizations(registration_number)
        representative =
          Veteran::Service::Representative.veteran_service_officers.find_by(
            representative_id: registration_number
          )

        return [] if representative.nil?

        organizations =
          Veteran::Service::Organization.where(
            poa: representative.poa_codes
          )

        organizations.map do |organization|
          yield(
            poa_code: organization.poa,
            can_accept_digital_poa_requests:
              organization.can_accept_digital_poa_requests
          )
        end
      end
    end

    def accepts_digital_power_of_attorney_requests?
      can_accept_digital_poa_requests
    end
  end
end
