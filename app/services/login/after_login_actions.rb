# frozen_string_literal: true

require 'login/errors'

module Login
  class AfterLoginActions
    include Accountable

    attr_reader :current_user

    def initialize(user)
      @current_user = user
    end

    def perform
      return unless current_user

      evss_create_account
      user_verification_create_or_update
      update_account_login_stats(login_type)

      if Settings.test_user_dashboard.env == 'staging'
        TestUserDashboard::UpdateUser.new(current_user).call(Time.current)
        TestUserDashboard::AccountMetrics.new(current_user).checkout
      end
    end

    private

    def login_type
      @login_type ||= current_user.identity.sign_in[:service_name]
    end

    def evss_create_account
      if current_user.authorize(:evss, :access?)
        auth_headers = EVSS::AuthHeaders.new(current_user).to_h
        EVSS::CreateUserAccountJob.perform_async(auth_headers)
      end
    end

    # Queries for a UserVerification on the user, based off the credential identifier
    # If a UserVerification doesn't exist, create one and a UserAccount record associated
    # with that UserVerification
    def user_verification_create_or_update
      case login_type
      when SAML::User::MHV_MAPPED_CSID
        find_or_create_user_verification(:mhv_uuid, current_user.mhv_correlation_id)
      when SAML::User::IDME_CSID
        find_or_create_user_verification(:idme_uuid, current_user.idme_uuid)
      when SAML::User::DSLOGON_CSID
        find_or_create_user_verification(:dslogon_uuid, current_user.identity.edipi)
      when SAML::User::LOGINGOV_CSID
        find_or_create_user_verification(:logingov_uuid, current_user.logingov_uuid)
      else
        Rails.logger.info(
          "[AfterLoginActions] Unknown or missing login_type for user=#{current_user.uuid}, login_type=#{login_type}"
        )

        raise Login::Errors::UnknownLoginTypeError
      end
    rescue => e
      Rails.logger.info("[AfterLoginActions] UserVerification cannot be created or updated, error=#{e.message}")
    end

    def find_or_create_user_verification(type, identifier)
      if identifier.nil?
        Rails.logger.info("[AfterLoginActions] Nil identifier for type=#{type}")

        # ID.me uuid has historically been a primary identifier, even for non-ID.me credentials.
        # For now it is still worth attempting to use it as a backup identifier
        type = :idme_uuid
        identifier = current_user.idme_uuid
        raise Login::Errors::UserVerificationNotCreatedError if identifier.nil?

        Rails.logger.info("[AfterLoginActions] Attempting alternate type=#{type}  identifier=#{identifier}")
      end

      user_verification = UserVerification.find_by(type => identifier)
      current_user_icn = current_user.icn.presence
      user_account = current_user_icn ? UserAccount.find_by(icn: current_user_icn) : nil

      if user_verification
        update_existing_user_verification(user_verification, current_user_icn, user_account)
      else
        verified_at = current_user.icn.present? ? Time.zone.now : nil
        UserVerification.create!(type => identifier,
                                 user_account: user_account || UserAccount.new(icn: current_user_icn),
                                 verified_at: verified_at)
      end
    end

    def update_existing_user_verification(user_verification, user_icn, user_account)
      return user_verification if user_icn.nil? || user_verification.user_account == user_account

      if user_account
        deprecated_user_account = user_verification.user_account
        DeprecatedUserAccount.create!(user_account: deprecated_user_account,
                                      user_verification: user_verification)
        user_verification.update(user_account: user_account, verified_at: Time.zone.now)
        Rails.logger.info("[AfterLoginActions] Deprecating UserAccount id=#{deprecated_user_account.id}, " \
                          "Updating UserVerification id=#{user_verification.id} with UserAccount id=#{user_account.id}")
      else
        user_verification_account = user_verification.user_account
        user_verification_account.update(icn: user_icn)
        user_verification.update(verified_at: Time.zone.now)
      end
    end
  end
end
