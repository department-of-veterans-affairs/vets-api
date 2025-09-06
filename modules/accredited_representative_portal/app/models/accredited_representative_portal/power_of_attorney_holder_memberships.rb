# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyHolderMemberships
    Membership =
      Data.define(
        :registration_number,
        :power_of_attorney_holder
      )

    Error = Class.new(RuntimeError)
    InvalidRegistrationsError = Class.new(Error)

    def initialize(icn:, emails:)
      @icn = icn
      @emails = emails
      @ogc_client = OgcClient.new
    end

    Types = PowerOfAttorneyHolder::Types

    ##
    # `#load` always returns an `Array` of `Membership` objects with:
    #   - a unique `registration_number`
    #   - a `power_of_attorney_holder` having a type that is one of:
    #     - `VETERAN_SERVICE_ORGANIZATION`
    #     - `CLAIMS_AGENT`
    #     - `ATTORNEY`
    #
    # `VETERAN_SERVICE_ORGANIZATION`s may account for multiple memberships (one
    # per matching organization), while `CLAIMS_AGENT` and `ATTORNEY` account
    # for exactly one each.
    #
    # No unsupported user types are included, and duplicate or empty
    # registration sets raise `InvalidRegistrationsError`.
    #
    def load # rubocop:disable Metrics/MethodLength
      @memberships ||=
        get_registrations.flat_map do |registration|
          case registration.user_type
          when 'veteran_service_officer'
            organizations =
              Veteran::Service::Organization.where(
                poa: registration.poa_codes
              )

            organizations.map do |organization|
              Membership.new(
                registration_number:
                  registration.representative_id,

                power_of_attorney_holder:
                  PowerOfAttorneyHolder.new(
                    type: Types::VETERAN_SERVICE_ORGANIZATION,
                    poa_code: organization.poa,
                    can_accept_digital_poa_requests:
                      organization.can_accept_digital_poa_requests
                  )
              )
            end
          when 'claims_agent'
            Membership.new(
              registration_number:
                registration.representative_id,

              power_of_attorney_holder:
                PowerOfAttorneyHolder.new(
                  type: Types::CLAIMS_AGENT,
                  poa_code: registration.poa_codes.first,
                  can_accept_digital_poa_requests:
                    false
                )
            )
          when 'attorney'
            Membership.new(
              registration_number:
                registration.representative_id,

              power_of_attorney_holder:
                PowerOfAttorneyHolder.new(
                  type: Types::ATTORNEY,
                  poa_code: registration.poa_codes.first,
                  can_accept_digital_poa_requests:
                    false
                )
            )
          else
            []
          end
        end
    end

    private

    def get_registrations
      registrations = get_upstream_registrations
      unless registrations.empty?
        ##
        # TODO: Should we be validating upstream registrations the way we've
        # been doing with record registrations?
        #
        validate_uniqueness!(registrations)
        return registrations
      end

      get_record_registrations.tap do |registrations|
        validate_nonempty!(registrations)
        validate_uniqueness!(registrations)

        registrations.each do |registration|
          ##
          # TODO: If one of these record registrations is found to be invalid,
          # but we've already written some other record registrations upstream
          # earlier, then should we have the onus to undo the ones that were
          # written earlier?
          #
          number = registration.representative_id
          put_upstream_registration!(number)
        end
      end
    rescue InvalidRegistrationsError => e
      ##
      # TODO: This is inappropriately hijacking the caller's responsibility to
      # transform a business logic error, `InvalidRegistrationsError`, to an
      # HTTP API representation, `Common::Exceptions::Forbidden`.
      #
      raise Common::Exceptions::Forbidden, detail: e.message
    end

    def put_upstream_registration!(number)
      result =
        @ogc_client.post_icn_and_registration_combination(
          @icn, number
        )

      result == :conflict and
        raise InvalidRegistrationsError, <<~MSG.squish
          ICN is already associated with a different registration.
        MSG
    end

    def get_upstream_registrations
      representative_id =
        @ogc_client.find_registration_numbers_for_icn(@icn).to_a

      Veteran::Service::Representative.where(
        representative_id:
      ).to_a
    end

    def get_record_registrations
      email =
        @emails.map(&:downcase)

      Veteran::Service::Representative.where(
        %{LOWER(email) IN (:email)}, email:
      ).to_a
    end

    def validate_uniqueness!(registrations)
      groups = registrations.group_by(&:user_type)
      groups.values.any?(&:many?) and
        raise InvalidRegistrationsError, <<~MSG.squish
          Multiple registrations of the same type found.
        MSG
    end

    def validate_nonempty!(registrations)
      registrations.empty? and
        raise InvalidRegistrationsError, <<~MSG.squish
          No registrations found.
        MSG
    end
  end
end
