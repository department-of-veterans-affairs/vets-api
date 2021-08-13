# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'rest-client'
require 'saml/settings_service'
require 'sentry_logging'
require 'oidc/key_service'
require 'okta/user_profile'
require 'okta/service'
require 'jwt'
require 'base64'

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

    # Only want to fetch the Okta profile if the session isn't already established and not a CC token
    @session = Session.find(hash_token(token)) unless token.client_credentials_token?
    profile = @session.profile unless @session.nil? || @session.profile.nil?
    profile = fetch_profile(token.identifiers.okta_uid) unless token.client_credentials_token? || !profile.nil?
    populate_ssoi_token_payload(profile) if !profile.nil? && profile.attrs['last_login_type'] == 'ssoi'

    if @session.nil? && !token.client_credentials_token?
      establish_session(profile)
      return false if @session.nil?
    end

    # issued for a client vs a user
    if token.client_credentials_token? || token.ssoi_token?
      populate_payload_for_launch_patient_scope if token.payload['scp'].include?('launch/patient')
      populate_payload_for_launch_scope if token.payload['scp'].include?('launch')
      return true
    end

    return false if @session.uuid.nil?

    @current_user = OpenidUser.find(@session.uuid)
    confirm_icn_match(profile)
  end

  def populate_payload_for_launch_scope
    analyze_redis_launch_context
    token.payload[:launch] =
      base64_json?(@session.launch) ? JSON.parse(Base64.decode64(@session.launch)) : { patient: @session.launch }
  end

  def populate_payload_for_launch_patient_scope
    analyze_redis_launch_context
    token.payload[:icn] = @session.launch
    token.payload[:launch] = { patient: @session.launch } unless @session.launch.nil?
  end

  def analyze_redis_launch_context
    @session = Session.find(hash_token(token))
    # Sessions are not originally created for client credentials tokens, one will be created here.
    if @session.nil?
      ttl = token.payload['exp'] - Time.current.utc.to_i
      launch = fetch_smart_launch_context
      @session = build_launch_session(ttl, launch)
      @session.save
    # Launch context is not attached to the session for SSOi tokens, it will be added here.
    elsif @session.launch.nil?
      @session.launch = fetch_smart_launch_context
      @session.save
    end
  end

  def populate_ssoi_token_payload(profile)
    token.payload['last_login_type'] = 'ssoi'
    token.payload['icn'] = profile.attrs['icn']
    token.payload['npi'] = profile.attrs['npi']
    token.payload['sec_id'] = profile.attrs['SecID']
    token.payload['vista_id'] = profile.attrs['VistaId']
  end

  def token_from_request
    auth_request = request.authorization.to_s
    return unless auth_request[TOKEN_REGEX]

    token_string = auth_request.sub(TOKEN_REGEX, '').gsub(/^"|"$/, '')

    if jwt?(token_string)
      Token.new(token_string, fetch_aud)
    else
      # Future block for opaque tokens
      raise error_klass('Invalid token.')
    end
  end

  def base64_json?(launch_string)
    JSON.parse(Base64.decode64(launch_string))
    true
  rescue JSON::ParserError
    false
  end

  def jwt?(token_string)
    JWT.decode(token_string, nil, false, algorithm: 'RS256')
    true
  rescue JWT::DecodeError
    false
  end

  def error_klass(error_detail_string)
    # Errors from the jwt gem (and other dependencies) are reraised with
    # this class so we can exclude them from Sentry without needing to know
    # all the classes used by our dependencies.
    Common::Exceptions::TokenValidationError.new(detail: error_detail_string)
  end

  def establish_session(profile)
    ttl = token.payload['exp'] - Time.current.utc.to_i

    user_identity = OpenidUserIdentity.build_from_okta_profile(uuid: token.identifiers.uuid, profile: profile, ttl: ttl)
    @current_user = OpenidUser.build_from_identity(identity: user_identity, ttl: ttl)
    @session = build_session(ttl,
                             Okta::UserProfile.new({ 'last_login_type' => profile['last_login_type'],
                                                     'SecID' => profile['SecID'], 'VistaId' => profile['VistaId'],
                                                     'npi' => profile['npi'], 'icn' => profile['icn'] }))
    @session.save && user_identity.save && @current_user.save
  end

  # Ensure the Okta profile ICN continues to match the MPI ICN
  # If mismatched, revoke in Okta, set @session to nil, and return false
  # POA support (profile['icn'].nil?)
  def confirm_icn_match(profile)
    # Temporarily log only to get an accurate count of this issue
    # Okta::Service.new.clear_user_session(token.identifiers.okta_uid)
    # @session = nil
    log_message_to_sentry('Profile ICN mismatch detected.', :warn) unless
        profile['icn'].nil? || @current_user&.icn == profile['icn']
    true
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

  def build_session(ttl, profile)
    session = Session.new(token: hash_token(token), uuid: token.identifiers.uuid, profile: profile)
    session.expire(ttl)
    session
  end

  def build_launch_session(ttl, launch)
    session = Session.new(token: hash_token(token), launch: launch)
    session.expire(ttl)
    session
  end

  def fetch_aud
    Settings.oidc.isolated_audience.default
  end

  def fetch_smart_launch_context
    response = RestClient.get(Settings.oidc.smart_launch_url,
                              { Authorization: 'Bearer ' + token.token_string })
    raise error_klass('Invalid launch context') if response.nil?

    if response.code == 200
      json_response = JSON.parse(response.body)
      json_response['launch']
    end
  rescue => e
    log_message_to_sentry('Error retrieving smart launch context for OIDC token: ' + e.message, :error)
    raise error_klass('Invalid launch context')
  end

  def hash_token(token)
    Digest::SHA256.hexdigest(token.to_s)
  end
  attr_reader :current_user, :session, :scopes
end
