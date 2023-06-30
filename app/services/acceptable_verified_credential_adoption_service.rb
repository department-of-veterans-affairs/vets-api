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

    return if email.blank?

    VANotify::EmailJob.perform_async(
      email,
      REACTIVATION_TEMPLATE,
      {
        # personalization stuff goes here
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
    (logged_in_with_dsl? || logged_in_with_mhv?) && verified_credential_at?
  end

  def logged_in_with_dsl?
    credential_type == SAML::User::DSLOGON_CSID
  end

  def logged_in_with_mhv?
    credential_type == SAML::User::MHV_ORIGINAL_CSID
  end

  def verified_credential_at?
    user_avc = UserAcceptableVerifiedCredential.find_by(user_account: user.user_account)
    user_avc&.acceptable_verified_credential_at || user_avc&.idme_verified_credential_at
  end

  def log_results(conversion_type)
    StatsD.increment("#{STATS_KEY}.#{conversion_type}.#{credential_type}")
  end
end
