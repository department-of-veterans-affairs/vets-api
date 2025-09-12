# frozen_string_literal: true

module AccreditedRepresentativePortal
  class RepresentativeUserAccount < UserAccount
    def set_all_emails(all_emails)
      @all_emails = all_emails
    end

    ##
    # TODO: Rename or otherwise refactor callers. `active_` does not helpfully
    # describe the purpose of this method, which is to return POA holders that
    # accept digital POA requests.
    #
    def active_power_of_attorney_holders
      power_of_attorney_holders
        .select(&:accepts_digital_power_of_attorney_requests?)
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

    def get_registration_number(power_of_attorney_holder_type)
      registrations.each do |registration|
        next unless registration.power_of_attorney_holder_type == power_of_attorney_holder_type

        return registration.accredited_individual_registration_number
      end

      nil
    end

    def registrations
      @registration_numbers ||= registration_numbers

      @registrations ||= @registration_numbers.map do |user_type, registration_number|
        OpenStruct.new(
          accredited_individual_registration_number: registration_number,
          power_of_attorney_holder_type: map_user_type(user_type)
        )
      end
    end

    private

    def map_user_type(user_type)
      case user_type
      when 'veteran_service_officer'
        PowerOfAttorneyHolder::Types::VETERAN_SERVICE_ORGANIZATION
      else
        user_type
      end
    end

    # rubocop:disable Metrics/MethodLength
    def registration_numbers
      registration_nums = AccreditedRepresentativePortal::OgcClient.new.find_registration_numbers_for_icn(icn)

      if registration_nums.blank?
        representatives = Veteran::Service::Representative.where('LOWER(email) IN (?)', @all_emails.map(&:downcase))

        if representatives.empty?
          raise Common::Exceptions::Forbidden, detail: 'No representatives found for this user.'
        elsif representatives.group_by(&:user_type).any? { |_, group| group.many? }
          raise Common::Exceptions::Forbidden, detail: 'Multiple representatives of the same type found for this user.'
        end

        representatives.each do |rep|
          result = AccreditedRepresentativePortal::OgcClient.new.post_icn_and_registration_combination(
            icn, rep.representative_id
          )

          # Handle conflict response
          if result == :conflict
            raise Common::Exceptions::Forbidden, detail: 'ICN is already registered with a different representative.'
          end
        end
      else
        # find types for numbers from api
        representatives = Veteran::Service::Representative.where(representative_id: registration_nums)
      end

      representatives.each_with_object({}) do |rep, map|
        map[rep.user_type] = rep.representative_id
      end
    end
    # rubocop:enable Metrics/MethodLength

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
