# frozen_string_literal: true

require 'login/errors'

module Login
  class UserVerifier
    attr_reader :user_uuid, :login_type, :mhv_uuid, :idme_uuid, :dslogon_uuid, :logingov_uuid, :icn

    def initialize(user)
      @user_uuid = user.uuid
      @login_type = user.identity.sign_in&.dig(:service_name)
      @mhv_uuid = user.mhv_correlation_id
      @idme_uuid = user.idme_uuid
      @dslogon_uuid = user.identity.edipi
      @logingov_uuid = user.logingov_uuid
      @icn = user.icn.presence
    end

    def perform
      user_verification_create_or_update
    end

    private

    # Queries for a UserVerification on the user, based off the credential identifier
    # If a UserVerification doesn't exist, create one and a UserAccount record associated
    # with that UserVerification
    def user_verification_create_or_update
      case login_type
      when SAML::User::MHV_MAPPED_CSID
        find_or_create_user_verification(:mhv_uuid, mhv_uuid)
      when SAML::User::IDME_CSID
        find_or_create_user_verification(:idme_uuid, idme_uuid)
      when SAML::User::DSLOGON_CSID
        find_or_create_user_verification(:dslogon_uuid, dslogon_uuid)
      when SAML::User::LOGINGOV_CSID
        find_or_create_user_verification(:logingov_uuid, logingov_uuid)
      else
        Rails.logger.info(
          "[Login::UserVerifier] Unknown or missing login_type for user=#{user_uuid}, login_type=#{login_type}"
        )

        raise Login::Errors::UnknownLoginTypeError
      end
    end

    def find_or_create_user_verification(type, identifier)
      if identifier.nil?
        Rails.logger.info("[Login::UserVerifier] Nil identifier for type=#{type}")

        # ID.me uuid has historically been a primary identifier, even for non-ID.me credentials.
        # For now it is still worth attempting to use it as a backup identifier
        type = :idme_uuid
        identifier = idme_uuid
        raise Login::Errors::UserVerificationNotCreatedError if identifier.nil?

        Rails.logger.info("[Login::UserVerifier] Attempting alternate type=#{type}  identifier=#{identifier}")
      end

      user_verification = UserVerification.find_by(type => identifier)

      user_account = icn ? UserAccount.find_by(icn: icn) : nil

      if user_verification
        update_existing_user_verification(user_verification, user_account)
      else
        verified_at = icn ? Time.zone.now : nil
        user_verification = UserVerification.create!(type => identifier,
                                                     user_account: user_account ||
                                                                   UserAccount.new(icn: icn),
                                                     verified_at: verified_at)
      end
      user_verification.reload
    end

    def update_existing_user_verification(user_verification, user_account)
      return user_verification if icn.nil? || user_verification.user_account == user_account

      if user_account
        deprecated_user_account = user_verification.user_account
        DeprecatedUserAccount.create!(user_account: deprecated_user_account,
                                      user_verification: user_verification)
        user_verification.update(user_account: user_account, verified_at: Time.zone.now)
        Rails.logger.info("[Login::UserVerifier] Deprecating UserAccount id=#{deprecated_user_account.id}, " \
                          "Updating UserVerification id=#{user_verification.id} with UserAccount id=#{user_account.id}")
      else
        user_verification_account = user_verification.user_account
        user_verification_account.update(icn: icn)
        user_verification.update(verified_at: Time.zone.now)
      end
    end
  end
end
