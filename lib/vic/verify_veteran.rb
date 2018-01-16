# frozen_string_literal: true
module VIC
  module VerifyVeteran
    module_function

    def create_mvi_profile(attributes)
      mvi_profile = MVI::Models::MviProfile.new
      veteran_full_name = attributes['veteran_full_name']
      mvi_profile.given_names = []
      %w(first middle).each do |name|
        mvi_profile.given_names << veteran_full_name[name]
      end
      mvi_profile.given_names.compact!
      mvi_profile.family_name = attributes['veteran_full_name']['last']
      mvi_profile.birth_date = attributes['veteran_date_of_birth']
      mvi_profile.ssn = attributes['veteran_social_security_number']
      mvi_profile.gender = attributes['gender']

      mvi_profile
    end

    def verify_veteran(attributes)
      mvi_profile = create_mvi_profile(attributes)
      mvi_response_profile = MVI::Service.new.find_profile_from_mvi_profile(mvi_profile)&.profile
      return false if mvi_response_profile.blank?

      emis_opt = {}
      mvi_response_profile.edipi ? emis_opt[:edipi] = mvi_response_profile.edipi : emis_opt[:icn] = mvi_response_profile.icn
      return false if emis_opt.values.compact.blank?

      emis_response = EMIS::VeteranStatusService.new.get_veteran_status(emis_opt)
      raise emis_response.error if emis_response.error?
      veteran_status = emis_response.items.first
      return false if veteran_status.blank?

      if User::ID_CARD_ALLOWED_STATUSES.include?(veteran_status.title38_status_code)
        service_branches = EMIS::MilitaryInformationService.new.get_military_service_episodes(emis_opt).items.map(&:branch_of_service)
        address = mvi_response_profile.address

        return {
          veteran_address: {
            country: address.country,
            street: address.street,
            city: address.city,
            state: address.state,
            postal_code: address.postal_code
          },
          phone: mvi_response_profile.home_phone,
          service_branches: service_branches
        }
      end

      false
    end
  end
end
