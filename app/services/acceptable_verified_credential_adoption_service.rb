# frozen_string_literal: true

##
# Supports the transition to an Acceptable Verified Credential
#
# @param user
#
class AcceptableVerifiedCredentialAdoptionService
  attr_accessor :user

  def initialize(user)
    @user = user
  end

  def perform
    display_organic_modal_for_logingov_conversion
  end

  private

  def result
    @result ||= {}
  end

  def display_organic_modal_for_logingov_conversion
    result[:organic_modal] =
      Flipper.enabled?(:organic_dsl_conversion_experiment, user) && user_qualifies_for_conversion?
    result
  end

  def user_qualifies_for_conversion?
    logged_in_with_dsl? && !verified_credential_at?
  end

  def logged_in_with_dsl?
    user.identity.sign_in[:service_name] == SAML::User::DSLOGON_CSID
  end

  def verified_credential_at?
    user_avc = UserAcceptableVerifiedCredential.find_by(user_account: user.user_account)
    user_avc&.acceptable_verified_credential_at || user_avc&.idme_verified_credential_at
  end
end
