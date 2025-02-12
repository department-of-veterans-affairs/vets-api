# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength
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

    PRIMARY_KEY_ATTRIBUTE_NAMES = %i[
      type
      poa_code
    ].freeze

    class << self
      # The `for_user` method retrieves the Power of Attorney (POA) holders associated with a user
      # based on their email and ICN (Integration Control Number).
      #
      # Why this method exists:
      # - The purpose of this method is to determine which VSOs (veteran service organizations)
      #   a given user (representative) belongs to.
      # - It first looks up the accredited representative using `reconcile_and_find_by`, which
      #   ensures that both email and ICN associations are accurate.
      # - If a match is found, it retrieves the accredited representative's registration number
      #   and finds their associated POA organizations.
      #
      # How it works:
      # - It queries `UserAccountAccreditedIndividual` to find a representative linked to the user.
      # - If the `power_of_attorney_holder_type` is `VETERAN_SERVICE_ORGANIZATION`, it:
      #   - Fetches the representative's POA codes.
      #   - Uses these POA codes to retrieve associated organizations.
      #   - Creates and returns a list of `PowerOfAttorneyHolder` instances, including whether
      #     each organization can accept digital POA requests.
      #
      def for_user(email:, icn:)
        [].tap do |poa_holders|
          records =
            Array.wrap(
              UserAccountAccreditedIndividual.reconcile_and_find_by(
                user_account_email: email,
                user_account_icn: icn
              )
            )

          records.each do |record|
            case record.power_of_attorney_holder_type
            when Types::VETERAN_SERVICE_ORGANIZATION
              representative_id = record.accredited_individual_registration_number
              representative = Veteran::Service::Representative.find_by(representative_id:)

              poa_codes = representative.poa_codes.to_a
              organizations = Veteran::Service::Organization.find_by(poa: poa_codes)

              organizations.each do |organization|
                poa_holder =
                  PowerOfAttorneyHolder.new(
                    type: record.power_of_attorney_holder_type,
                    poa_code: organization.poa,
                    can_accept_digital_poa_requests:
                      organization.can_accept_digital_poa_requests
                  )

                poa_holders.push(
                  poa_holder
                )
              end
            end
          end
        end
      end
    end

    def accepts_digital_power_of_attorney_requests?
      can_accept_digital_poa_requests
    end
  end
end
# rubocop:enable Metrics/MethodLength
