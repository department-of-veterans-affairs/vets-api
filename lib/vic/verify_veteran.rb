# frozen_string_literal: true

module VIC
  module VerifyVeteran
    module_function

    def create_mvi_profile(attributes)
      mvi_profile = MVI::Models::MviProfile.new
      veteran_full_name = attributes['veteran_full_name']
      mvi_profile.given_names = []
      %w[first middle].each do |name|
        mvi_profile.given_names << veteran_full_name[name]
      end
      mvi_profile.given_names.compact!
      mvi_profile.family_name = attributes['veteran_full_name']['last']
      mvi_profile.birth_date = attributes['veteran_date_of_birth']
      mvi_profile.ssn = attributes['veteran_social_security_number']
      mvi_profile.gender = attributes['gender']

      mvi_profile
    end

    def send_request(veteran_attributes)
      mvi_profile = create_mvi_profile(veteran_attributes)
      mvi_response_profile = MVI::Service.new.find_profile_from_mvi_profile(mvi_profile)&.profile
      return false if mvi_response_profile.blank?

      emis_request_options = mvi_response_profile.emis_request_options
      return false if emis_request_options.blank?

      emis_response = EMIS::VeteranStatusService.new.get_veteran_status(emis_request_options)
      veteran_status = emis_response.items.first
      return false if veteran_status.blank?

      User::ID_CARD_ALLOWED_STATUSES.include?(veteran_status.title38_status_code)
    end
  end
end
