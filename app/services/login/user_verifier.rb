# frozen_string_literal: true

require 'login/errors'

module Login
  class UserVerifier
    def initialize(user)
      @user_uuid = user.uuid
      @login_type = user.identity.sign_in&.dig(:service_name)
      @mhv_uuid = user.mhv_correlation_id
      @idme_uuid = user.idme_uuid
      @dslogon_uuid = user.identity.edipi
      @logingov_uuid = user.logingov_uuid
      @icn = user.icn.presence
      @deprecated_log = nil
    end

    def perform
      find_or_create_user_verification
    end

    private

    attr_reader :user_uuid, :login_type, :mhv_uuid, :idme_uuid, :dslogon_uuid, :logingov_uuid, :icn, :deprecated_log

    MHV_TYPE = :mhv_uuid
    IDME_TYPE = :idme_uuid
    DSLOGON_TYPE = :dslogon_uuid
    LOGINGOV_TYPE = :logingov_uuid

    # Queries for a UserVerification on the user, based off the credential identifier
    # If a UserVerification doesn't exist, create one and a UserAccount record associated
    # with that UserVerification
    def find_or_create_user_verification
      if identifier.nil?
        Rails.logger.info("[Login::UserVerifier] Nil identifier for type=#{type}")
        attempt_secondary_idme_identifier
      end

      ActiveRecord::Base.transaction do
        update_existing_user_verification if user_verification_needs_to_be_updated?
        create_user_verification if user_verification.nil?
      rescue Errors::VerifiedUserAccountMismatch => e
        Rails.logger.info(
          "[Login::UserVerifier] User Account Mismatch for UserVerification id=#{user_verification.id}, " \
          "UserAccount id=#{user_verification.user_account.id}, icn=#{user_verification.user_account.icn}, " \
          "conflicts with UserAccount id=#{existing_user_account.id} icn=#{existing_user_account.icn}"
        )
        raise e
      end

      Rails.logger.info(deprecated_log) if deprecated_log
      user_verification
    end

    def update_existing_user_verification
      if existing_user_account
        if user_verification.verified?
          raise Errors::VerifiedUserAccountMismatch
        else
          deprecate_unverified_user_account
        end
      else
        update_newly_verified_user
      end
    end

    def deprecate_unverified_user_account
      deprecated_user_account = user_verification.user_account
      DeprecatedUserAccount.create!(user_account: deprecated_user_account,
                                    user_verification: user_verification)
      user_verification.update(user_account: existing_user_account, verified_at: Time.zone.now)
      set_deprecated_log(deprecated_user_account.id, user_verification.id, existing_user_account.id)
    end

    def update_newly_verified_user
      user_verification_account = user_verification.user_account
      user_verification.update(verified_at: Time.zone.now)
      user_verification_account.update(icn: icn)
    end

    def create_user_verification
      verified_at = icn ? Time.zone.now : nil
      UserVerification.create!(type => identifier,
                               user_account: existing_user_account ||
                               UserAccount.new(icn: icn),
                               verified_at: verified_at)
    end

    def user_verification_needs_to_be_updated?
      user_verification && icn.present? && user_verification.user_account != existing_user_account
    end

    def set_deprecated_log(deprecated_user_account_id, user_verification_id, user_account_id)
      @deprecated_log = "[Login::UserVerifier] Deprecating UserAccount id=#{deprecated_user_account_id}, " \
                        "Updating UserVerification id=#{user_verification_id} with UserAccount id=#{user_account_id}"
    end

    # ID.me uuid has historically been a primary identifier, even for non-ID.me credentials.
    # For now it is still worth attempting to use it as a backup identifier
    def attempt_secondary_idme_identifier
      @type = :idme_uuid
      @identifier = idme_uuid
      raise Errors::UserVerificationNotCreatedError if identifier.nil?

      Rails.logger.info("[Login::UserVerifier] Attempting alternate type=#{type}  identifier=#{identifier}")
    end

    def existing_user_account
      @existing_user_account ||= icn ? UserAccount.find_by(icn: icn) : nil
    end

    def user_verification
      @user_verification ||= identifier ? UserVerification.find_by(type => identifier) : nil
    end

    def type
      @type ||= case login_type
                when SAML::User::MHV_MAPPED_CSID
                  MHV_TYPE
                when SAML::User::IDME_CSID
                  IDME_TYPE
                when SAML::User::DSLOGON_CSID
                  DSLOGON_TYPE
                when SAML::User::LOGINGOV_CSID
                  LOGINGOV_TYPE
                else
                  Rails.logger.info(
                    '[Login::UserVerifier] Unknown or missing login_type ' \
                    "for user=#{user_uuid}, login_type=#{login_type}"
                  )

                  raise Errors::UnknownLoginTypeError
                end
    end

    def identifier
      @identifier ||= case type
                      when MHV_TYPE
                        mhv_uuid
                      when IDME_TYPE
                        idme_uuid
                      when DSLOGON_TYPE
                        dslogon_uuid
                      when LOGINGOV_TYPE
                        logingov_uuid
                      end
    end
  end
end
