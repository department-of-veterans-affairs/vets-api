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
    @current_user = OpenidUser.find(@session.uuid)
  end

  def token_from_request
    auth_request = request.authorization.to_s
    return unless auth_request[TOKEN_REGEX]
    auth_request.sub(TOKEN_REGEX, '').gsub(/^"|"$/, '')
  end

  def establish_session
    validate_token
    ttl = token_payload['exp'] - Time.current.utc.to_i
    profile = fetch_profile(token_identifiers.okta_uid)
    user_identity = OpenidUserIdentity.build_from_okta_profile(uuid: token_identifiers.uuid, profile: profile, ttl: ttl)
    @current_user = OpenidUser.build_from_identity(identity: user_identity, ttl: ttl)
    @session = build_session(token, token_identifiers.uuid, ttl)
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
    raise 'Validation error: no payload to validate' unless token_payload
    raise 'Validation error: issuer' unless token_payload['iss'] == Settings.oidc.issuer
    raise 'Validation error: audience' unless token_payload['aud'] == Settings.oidc.audience
    raise 'Validation error: ttl' unless token_payload['exp'] >= Time.current.utc.to_i
  end

  def fetch_profile(uid)
    profile_response = Okta::Service.new.user(uid)
    if profile_response.success?
      Okta::UserProfile.new(profile_response.body['profile'])
    else
      log_message_to_sentry('Error retrieving profile for OIDC token', :error,
                            body: profile_response.body)
      raise 'Unable to retrieve user profile'
    end
  end

  def token_identifiers
    # Here the `sub` field is the same value as the `uuid` field from the original upstream ID.me
    # SAML response. We use this as the primary identifier of the user because, despite openid user
    # records being controlled by okta, we want to remain consistent with the va.gov SSO process
    # that consumes the SAML response directly, outside the openid flow.
    # Example of an upstream uuid for the user: cfa32244569841a090ad9d2f0524cf38
    # Example of an okta uid for the user: 00u2p9far4ihDAEX82p7
    @token_identifiers ||= OpenStruct.new(
      uuid: token_payload['sub'],
      okta_uid: token_payload['uid']
    )
  end

  def build_session(token, uuid, ttl)
    session = Session.new(token: token, uuid: uuid)
    session.expire(ttl)
    session
  end

  def expected_key(token)
    decoded_token = JWT.decode(token, nil, false, algorithm: 'RS256')
    kid = decoded_token[1]['kid']
    OIDC::KeyService.get_key(kid)
  end

  attr_reader :current_user, :session, :scopes
end
