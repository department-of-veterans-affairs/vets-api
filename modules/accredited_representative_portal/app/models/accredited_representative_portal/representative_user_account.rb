# frozen_string_literal: true

module AccreditedRepresentativePortal
  class RepresentativeUserAccount < UserAccount
    def set_email(email)
      @email.blank? or
        raise ArgumentError, 'Must not reset user email'

      @email = email
    end

    def active_power_of_attorney_holders
      power_of_attorney_holders
        .select(&:accepts_digital_power_of_attorney_requests?)
    end

    def get_registration_number(power_of_attorney_holder_type)
      registrations.each do |registration|
        next unless registration.power_of_attorney_holder_type == power_of_attorney_holder_type

        return registration.accredited_individual_registration_number
      end

      nil
    end

    private

    def registrations
      @email.present? or
        raise ArgumentError, 'Must set user email'
      if FeatureToggle.enabled?(:accredited_representative_portal_self_service_auth)
        @registrations ||= [
          OpenStruct.new(
            accredited_individual_registration_number: session.rep_registration_number,
            power_of_attorney_holder_type: 'veteran_service_organization', 
            user_account_email: @email,
            user_account_icn: icn
          )
        ]
      else
        @registrations ||=
          UserAccountAccreditedIndividual.for_user_account_email(
            @email, user_account_icn: icn
          )
      end
    end

    def power_of_attorney_holders
      @power_of_attorney_holders ||= registrations.flat_map do |registration|
        number = registration.accredited_individual_registration_number
        type = registration.power_of_attorney_holder_type

        case type
        when PowerOfAttorneyHolder::Types::VETERAN_SERVICE_ORGANIZATION
          ##
          # Other types are 1:1 and will have no reason to introduce a
          # complicated method that takes a block like this.
          #
          get_organizations(number) do |attrs|
            PowerOfAttorneyHolder.new(type:, **attrs)
          end
        else
          []
        end
      end
    end

    def get_organizations(representative_id)
      representative =
        Veteran::Service::Representative
        .veteran_service_officers
        .find_by(representative_id:)

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
end
