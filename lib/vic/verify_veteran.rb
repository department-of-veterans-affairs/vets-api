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
      given_names = []
      MVI::Models::MviProfile.new(
        given_names: attributes['veteran_full_name']
      )
      described_class.new.find_profile_from_mvi_profile(mvi_profile)
    end
  end
end
