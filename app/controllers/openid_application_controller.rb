# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'saml/settings_service'
require 'sentry_logging'
require 'oidc/key_service'
require 'okta/user_profile'
require 'okta/service'
require 'jwt'

class OpenidApplicationController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_after_action :set_csrf_header
  before_action :authenticate
  TOKEN_REGEX = /Bearer /.freeze

  private

  def permit_scopes(scopes, actions: [])
    return false unless token.payload

    if actions.empty? || Array.wrap(actions).map(&:to_s).include?(action_name)
      render_unauthorized if (Array.wrap(scopes) & token.payload['scp']).empty?
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

    Token.new(auth_request.sub(TOKEN_REGEX, '').gsub(/^"|"$/, ''), fetch_aud)
  end

  def establish_session
    ttl = token.payload['exp'] - Time.current.utc.to_i
    profile = fetch_profile(token.identifiers.okta_uid)
    user_identity = OpenidUserIdentity.build_from_okta_profile(uuid: token.identifiers.uuid, profile: profile, ttl: ttl)
    @current_user = OpenidUser.build_from_identity(identity: user_identity, ttl: ttl)
    @session = build_session(ttl)
    @session.save && user_identity.save && @current_user.save
  end

  def token
    @token ||= token_from_request
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

  def build_session(ttl)
    session = Session.new(token: token.to_s, uuid: token.identifiers.uuid)
    session.expire(ttl)
    session
  end

  def fetch_aud
    Settings.oidc.isolated_audience.default
  end

  attr_reader :current_user, :session, :scopes
end
