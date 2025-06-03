# frozen_string_literal: true

module AccreditedRepresentativePortal
  class RepresentativeUserAccount < UserAccount
    def set_email(email)
      @email.blank? or
        raise ArgumentError, 'Must not reset user email'

      @email = email
    end

    def set_all_emails(all_emails)
      @all_emails = all_emails
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

      if Flipper.enabled?(:accredited_representative_portal_self_service_auth)
        @registration_numbers ||= registration_numbers

        @registrations ||= @registration_numbers.map do |user_type, registration_number|
          OpenStruct.new(
            accredited_individual_registration_number: registration_number,
            power_of_attorney_holder_type: map_user_type(user_type)
          )
        end
      else
        # When we remove this we can also remove email as a single field
        @registrations ||= UserAccountAccreditedIndividual.for_user_account_email(
          @email, user_account_icn: icn
        )
      end
    end

    def map_user_type(user_type)
      case user_type
      when 'veteran_service_officer'
        PowerOfAttorneyHolder::Types::VETERAN_SERVICE_ORGANIZATION
      else
        user_type
      end
    end

    def registration_numbers
      registration_nums = AccreditedRepresentativePortal::OgcClient.new.find_registration_numbers_for_icn(icn)

      if registration_nums.blank?
        representatives = Veteran::Service::Representative.where(email: @all_emails)

        if representatives.empty?
          raise Common::Exceptions::Forbidden, detail: 'No representatives found for this user.'
        elsif representatives.group_by(&:user_type).any? { |_, group| group.many? }
          raise Common::Exceptions::Forbidden, detail: 'Multiple representatives of the same type found for this user.'
        end

        representatives.each do |rep|
          AccreditedRepresentativePortal::OgcClient.new.post_icn_and_registration_combination(icn,
                                                                                              rep.representative_id)
        end
      else
        # find types for numbers from api
        representatives = Veteran::Service::Representative.where(representative_id: registration_nums)
      end

      representatives.each_with_object({}) do |rep, map|
        map[rep.user_type] = rep.representative_id
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
