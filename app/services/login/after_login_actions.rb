# frozen_string_literal: true

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
          "[AfterLoginActions] Unknown or missing login_type for user:#{current_user.uuid}, login_type:#{login_type}"
        )
      end
    rescue => e
      Rails.logger.info("[AfterLoginActions] UserVerification cannot be created, error=#{e.message}")
    end

    def find_or_create_user_verification(credential_type, credential_identifier)
      return if UserVerification.find_by(credential_type => credential_identifier)

      UserVerification.create!(credential_type => credential_identifier, user_account: UserAccount.new(icn: nil))
    end
  end
end
