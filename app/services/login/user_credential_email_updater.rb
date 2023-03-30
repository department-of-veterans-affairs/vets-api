# frozen_string_literal: true

module Login
  class UserCredentialEmailUpdater
    def initialize(credential_email:, user_verification:)
      @credential_email = credential_email
      @user_verification = user_verification
    end

    def perform
      return unless user_verification && credential_email

      update_user_credential_email
    end

    private

    attr_reader :credential_email, :user_verification

    def update_user_credential_email
      user_credential_email = UserCredentialEmail.find_or_initialize_by(user_verification:)
      user_credential_email.credential_email = credential_email
      user_credential_email.save!
    end
  end
end
