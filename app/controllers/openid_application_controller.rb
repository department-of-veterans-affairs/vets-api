# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'saml/settings_service'
require 'sentry_logging'
require 'oidc/key_service'
require 'jwt'

class OpenidApplicationController < ApplicationController
  before_action :authenticate
  TOKEN_REGEX = /Bearer /

  DSLOGON_PREMIUM_LOAS = %w[2 3].freeze
  MHV_PREMIUM_LOAS = %w[Premium].freeze

  private

  def permit_scopes(scopes, actions: [])
    return false unless token_payload
    if actions.empty? || Array.wrap(actions).map(&:to_s).include?(action_name)
      render_unauthorized if (Array.wrap(scopes) & token_payload['scp']).empty?
    end
  end

  def authenticate
    authenticate_token || render_unauthorized
  end

  def authenticate_token
    return false if token.blank?
    @session = Session.find(token)
    establish_session if @session.nil?
    return false if @session.nil?
    @current_user = User.find(@session.uuid)
  end

  def token_from_request
    auth_request = request.authorization.to_s
    return unless auth_request[TOKEN_REGEX]
    auth_request.sub(TOKEN_REGEX, '').gsub(/^"|"$/, '')
  end

  def establish_session
    return false unless token_payload
    validate_token
    ttl = token_payload['exp'] - Time.current.utc.to_i
    user_identity = user_identity_from_profile(ttl)
    @current_user = user_from_identity(user_identity, ttl)
    @session = session_from_claims(ttl)
    @session.save && user_identity.save && @current_user.save
  rescue StandardError => e
    Rails.logger.warn(e)
  end

  def token
    @token ||= token_from_request
  end

  def token_payload
    @token_payload ||= if token
                         pubkey = expected_key(token)
                         return if pubkey.blank?
                         JWT.decode(token, pubkey, true, algorithm: 'RS256')[0]
                       end
  end

  def validate_token
    raise 'Validation error: issuer' unless token_payload['iss'] == Settings.oidc.issuer
    raise 'Validation error: audience' unless token_payload['aud'] == Settings.oidc.audience
    raise 'Validation error: ttl' unless token_payload['exp'] >= Time.current.utc.to_i
  end

  def user_identity_from_profile(ttl)
    uid = token_payload['uid']
    profile_response = Okta::Service.new.user(uid)
    if profile_response.success?
      profile = profile_response.body['profile']
      user_identity = UserIdentity.new(profile_to_attributes(token_payload, profile))
      user_identity.expire(ttl)
      user_identity
    else
      log_message_to_sentry('Error retrieving profile for OIDC token', :error,
                            body: profile_response.body)
      raise 'Unable to retrieve user profile'
    end
  end

  def profile_to_attributes(token_payload, profile)
    {
      uuid: token_payload['uid'],
      email: profile['email'],
      first_name: profile['firstName'],
      middle_name: profile['middleName'],
      last_name: profile['lastName'],
      mhv_icn: profile['icn'],
      loa: derive_loa(profile)
    }
  end

  def derive_loa(profile)
    if profile['last_login_type'] == 'myhealthevet'
      ml = MHV_PREMIUM_LOAS.include?(profile['mhv_account_type']) ? 3 : 1
      { current: ml, highest: ml }
    elsif profile['last_login_type'] == 'dslogon'
      dl = DSLOGON_PREMIUM_LOAS.include?(profile['dslogon_assurance']) ? 3 : 1
      { current: dl, highest: dl }
    else
      { current: profile['idme_loa']&.to_i, highest: profile['idme_loa']&.to_i }
    end
  end

  def user_from_identity(user_identity, ttl)
    user = User.new(user_identity.attributes)
    user.last_signed_in = Time.current.utc
    user.expire(ttl)
    user
  end

  def session_from_claims(ttl)
    session = Session.new(token: token, uuid: token_payload['uid'])
    session.expire(ttl)
    session
  end

  def expected_key(token)
    kid = (JWT.decode token, nil, false, algorithm: 'RS256')[1]['kid']
    OIDC::KeyService.get_key(kid)
  end

  attr_reader :current_user, :session, :scopes
end
