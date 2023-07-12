# frozen_string_literal: true

##
# Supports the transition to an Acceptable Verified Credential
#
# @param user
#
class AcceptableVerifiedCredentialAdoptionService
  attr_accessor :user

  REACTIVATION_TEMPLATE = Settings.vanotify.services.va_gov.template_id.login_reactivation_email
  STATS_KEY = 'api.user_transition_availability'

  def initialize(user)
    @user = user
  end

  def perform
    send_email if user_qualifies_for_reactivation? && Flipper.enabled?(:reactivation_experiment, user)
  end

  private

  def send_email
    email = user.email
    legacy_credential = logged_in_with_dsl? ? 'DS Logon' : 'My HealtheVet'
    modern_credential = user_avc&.acceptable_verified_credential_at ? 'Login.gov' : 'ID.me'

    return if email.blank?

    VANotify::EmailJob.perform_async(
      email,
      REACTIVATION_TEMPLATE,
      {
        'name' => user.first_name,
        'legacy_credential' => legacy_credential,
        'modern_credential' => modern_credential
      }
    )

    log_results('reactivation_email')
  end

  def result
    @result ||= {}
  end

  def credential_type
    @credential_type ||= user.identity.sign_in[:service_name]
  end

  def user_qualifies_for_reactivation?
    # uncomment after test is complete
    # (logged_in_with_dsl? || logged_in_with_mhv?) && verified_credential_at?

    # remove after test
    logged_in_with_dsl? && verified_credential_at?
  end

  def logged_in_with_dsl?
    credential_type == SAML::User::DSLOGON_CSID
  end

  def logged_in_with_mhv?
    credential_type == SAML::User::MHV_ORIGINAL_CSID
  end

  def user_avc
    @user_avc ||= UserAcceptableVerifiedCredential.find_by(user_account: user.user_account)
  end

  def verified_credential_at?
    # uncomment after test is complete
    # user_avc&.acceptable_verified_credential_at || user_avc&.idme_verified_credential_at

    # remove after test
    user_avc&.acceptable_verified_credential_at
  end

  def log_results(conversion_type)
    StatsD.increment("#{STATS_KEY}.#{conversion_type}.#{credential_type}")
  end
end
