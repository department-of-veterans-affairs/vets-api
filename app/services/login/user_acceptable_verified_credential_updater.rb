# frozen_string_literal: true

module Login
  class UserAcceptableVerifiedCredentialUpdater
    def initialize(user_account:)
      @user_account = user_account
    end

    def perform
      return unless user_account&.verified?

      update_user_acceptable_verified_credential
    end

    private

    attr_reader :user_account

    def update_user_acceptable_verified_credential
      user_avc = UserAcceptableVerifiedCredential.find_or_initialize_by(user_account:)
      user_avc.idme_verified_credential_at ||= Time.zone.now if idme_credential.present?
      user_avc.acceptable_verified_credential_at ||= Time.zone.now if logingov_credential.present?
      if user_avc.changed?
        user_avc.save!

        Login::UserAcceptableVerifiedCredentialUpdaterLogger.new(user_acceptable_verified_credential: user_avc).perform
      end
    end

    def idme_credential
      @idme_credential ||= user_verifications_array.where.not(idme_uuid: nil).first
    end

    def logingov_credential
      @logingov_credential ||= user_verifications_array.where.not(logingov_uuid: nil).first
    end

    def user_verifications_array
      @user_verifications_array ||= user_account.user_verifications
    end
  end
end
