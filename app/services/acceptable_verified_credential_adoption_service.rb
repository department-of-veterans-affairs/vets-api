# frozen_string_literal: true

##
# Supports the transition to an Acceptable Verified Credential
#
# @param user
#
class AcceptableVerifiedCredentialAdoptionService
  attr_accessor :user

  REACTIVATION_TEMPLATE_ID = '480270b2-d2c8-4048-91d7-aebc51a2f073'
  STATS_KEY = 'api.user_transition_availability'

  def initialize(user)
    @user = user
  end

  def perform
    send_email if eligible_for_sending?
  end

  private

  def send_email
    email = user.email
    legacy_credential = logged_in_with_dsl? ? 'DS Logon' : 'My HealtheVet'
    modern_credential = user_avc&.acceptable_verified_credential_at ? 'Login.gov' : 'ID.me'

    return if email.blank?

    VANotify::EmailJob.perform_async(
      email,
      REACTIVATION_TEMPLATE_ID,
      {
        'name' => user.first_name,
        'legacy_credential' => legacy_credential,
        'modern_credential' => modern_credential
      }
    )

    log_conversion_type_results('reactivation_email')
    record_adoption_email_trigger_event
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

  def log_conversion_type_results(conversion_type)
    StatsD.increment("#{STATS_KEY}.#{conversion_type}.#{credential_type}")
  end

  def record_adoption_email_trigger_event
    CredentialAdoptionEmailRecord.create(
      icn: user.icn,
      email_address: user.email,
      email_template_id: REACTIVATION_TEMPLATE_ID,
      email_triggered_at: DateTime.now
    )
  end

  def check_for_email_adoption_records
    CredentialAdoptionEmailRecord.where('email_triggered_at > ?', DateTime.now.days_ago(7)).where(icn: user.icn)
  end

  def recent_triggered_send?
    check_for_email_adoption_records.any?
  end

  def eligible_for_sending?
    # Thanks to Ruby's short circuit evaluation, our rate limiting via Flipper will only apply to eligible users.
    user.email && user_qualifies_for_reactivation? && !recent_triggered_send? && Flipper.enabled?(
      :reactivation_experiment_rate_limit, user
    )
  end
end
