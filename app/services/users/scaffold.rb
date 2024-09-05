# frozen_string_literal: true

module Users
  # Struct class serving as the pre-serialized object that is passed to the UserSerializer
  # during the '/v0/user' endpoint call.
  #
  # Note that with Struct's, parameter order matters.  Namely having `errors` first
  # and `status` second.
  #
  # rubocop:disable Style/StructInheritance
  class Scaffold < Struct.new(:errors, :status, :services, :account, :profile, :va_profile, :veteran_status,
                              :in_progress_forms, :prefills_available, :vet360_contact_information, :session,
                              :onboarding)
  end
  # rubocop:enable Style/StructInheritance
end
