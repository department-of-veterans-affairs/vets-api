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
      user_avc = UserAcceptableVerifiedCredential.find_or_initialize_by(user_account: user_account)
      user_avc.idme_verified_credential_at ||= Time.zone.now if includes_idme_credential?
      user_avc.acceptable_verified_credential_at ||= Time.zone.now if includes_logingov_credential?
      user_avc.save!
    end

    def includes_idme_credential?
      user_verification_array.where.not(idme_uuid: nil).present?
    end

    def includes_logingov_credential?
      user_verification_array.where.not(logingov_uuid: nil).present?
    end

    def user_verification_array
      @user_verification_array ||= user_account.user_verification
    end
  end
end
