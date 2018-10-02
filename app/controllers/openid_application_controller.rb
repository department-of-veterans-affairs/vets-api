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

  def authenticate
    authenticate_token || render_unauthorized
  end

  def authenticate_token
    token = token_from_request
    return false if token.blank?
    @session = Session.find(token)
    establish_session(token) if @session.nil?
    return false if @session.nil?
    @current_user = User.find(@session.uuid)
  end

  def token_from_request
    auth_request = request.authorization.to_s
    return unless auth_request[TOKEN_REGEX]
    auth_request.sub(TOKEN_REGEX, '').gsub(/^"|"$/, '')
  end

  def establish_session(token)
    pubkey = expected_key(token)
    return false if pubkey.blank?
    payload, = JWT.decode token, pubkey, true, algorithm: 'RS256'
    ttl = Time.current.utc.to_i - payload['iat']
    # TODO: add validation options - issuer, audience, cid
    user_identity = user_identity_from_profile(payload, ttl)
    @current_user = user_from_identity(user_identity, ttl)
    @session = session_from_claims(token, payload, ttl)
    @session.save && user_identity.save && @current_user.save
  rescue StandardError => e
    p e.message
    Rails.logger.warn(e)
  end

  def user_identity_from_profile(payload, ttl)
    uid = payload['uid']
    conn = Faraday.new(Settings.oidc.profile_api_url)
    profile_response = conn.get do |req|
      req.url uid
      req.headers['Content-Type'] = 'application/json'
      req.headers['Accept'] = 'application/json'
      req.headers['Authorization'] = "SSWS #{Settings.oidc.profile_api_token}"
    end
    # TODO: handle failure
    profile = JSON.parse(profile_response.body)['profile']
    user_identity = UserIdentity.new(profile_to_attributes(payload, profile))
    user_identity.expire(ttl)
    user_identity
  end

  def profile_to_attributes(payload, profile)
    {
      uuid: payload['uid'],
      email: profile['email'],
      first_name: profile['firstName'],
      middle_name: profile['middleName'],
      last_name: profile['lastName'],
      gender: profile['gender'],
      birth_date: profile['dob'],
      ssn: profile['ssn'],
      loa: { current: profile['loa'], highest: profile['loa'] }
    }
  end

  def user_identity_from_claims(payload, ttl)
    attributes = {
      uuid: payload['uid'],
      email: payload['sub'],
      first_name: payload['fn'],
      middle_name: payload['mn'],
      last_name: payload['ln'],
      gender: payload['gender'],
      birth_date: payload['dob'],
      ssn: payload['ssn'],
      loa: { current: payload['loa'], highest: payload['loa'] }
    }
    user_identity = UserIdentity.new(attributes)
    user_identity.expire(ttl)
    user_identity
  end

  def user_from_identity(user_identity, ttl)
    user = User.new(user_identity.attributes)
    user.expire(ttl)
    user
  end

  def session_from_claims(token, payload, ttl)
    session = Session.new(token: token, uuid: payload['uid'])
    session.expire(ttl)
    session
  end

  def expected_key(token)
    kid = (JWT.decode token, nil, false, algorithm: 'RS256')[1]['kid']
    OIDC::KeyService.get_key(kid)
  end

  attr_reader :current_user, :session, :scopes
end
