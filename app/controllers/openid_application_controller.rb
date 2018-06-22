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
    if auth_request[TOKEN_REGEX]
      auth_request = auth_request.sub(TOKEN_REGEX, '').gsub(%r/^"|"$/, '')
      return auth_request
    end
    nil
  end

#  [{"ver"=>1, 
#    "jti"=>"AT.7mXMI34GeSB7uR5RRRsLqUTwbmDAlwV8TshqmOU25JI", 
#    "iss"=>"https://deptva-vetsgov-eval.okta.com/oauth2/default", 
#    "aud"=>"api://default", 
#    "iat"=>1529553926, 
#    "exp"=>1529557526, 
#    "cid"=>"0oa1c01m77heEXUZt2p7", 
#    "uid"=>"00u1clhg0pZWZuQhm2p7", 
#    "scp"=>["openid", "profile", "email", "va_profile"], 
#    "sub"=>"vets.gov.user+32@gmail.com", 
#    "gender"=>"F", 
#    "dob"=>"19670619", 
#    "fn"=>"Tamara", 
#    "ln"=>"Ellis",
#    "ssn"=>"796130115", 
#    "loa"=>3}, 
#    {"kid"=>"M_Ucsb9dMgr0L3nIZYArsYfaHy3sY7W7ubwUh_Np0uw", 
#     "alg"=>"RS256"}]

  def establish_session(token)
    begin
      pubkey = expected_key(token)
      return false if pubkey.blank?
      payload, header = JWT.decode token, pubkey, true, { algorithm: 'RS256' }
      ttl = Time.current.utc.to_i - payload["iat"]
      # add validation options - issuer, audience, cid
      user_identity = user_identity_from_claims(payload, ttl)
      @current_user = user_from_identity(user_identity, ttl)
      @session = session_from_claims(token, payload, ttl)
      @session.save && @current_user.save && user_identity.save
    rescue StandardError => e
     Rails.logger.warn(e)
    end
  end

  def user_identity_from_claims(payload, ttl)
    attributes = {
      uuid: payload["uid"],
      email: payload["sub"],
      first_name: payload["fn"],
      middle_name: payload["mn"],
      last_name: payload["ln"],
      gender: payload["gender"],
      birth_date: payload["dob"],
      ssn: payload["ssn"],
      loa: {current: payload["loa"], highest: payload["loa"] }
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
    session = Session.new({ token: token, uuid: payload["uid"] })
    session.expire(ttl)
    session
  end

  def expected_key(token)
    kid = (JWT.decode token, nil, false, { algorithm: 'RS256' })[1]['kid']
    OIDC::KeyService.get_key(kid)
  end

  attr_reader :current_user, :session, :scopes
end
