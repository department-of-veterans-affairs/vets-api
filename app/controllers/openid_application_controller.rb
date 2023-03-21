# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'rest-client'
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
  TOKEN_REGEX = /Bearer /

  private

  def authenticate
    authenticate_token || render_unauthorized
  end

  def authenticate_token
    # First call to token instantiates it
    return false if token.blank?

    # Static tokens do not have a session built up at this time.
    return true if token.static?

    # Client credentials have no profile, so handled differently
    return populate_launch_context if token.client_credentials_token?

    # Only want to fetch the profile if the session isn't already established and not a CC token
    @session = Session.find(hash_token(token))
    profile = @session.profile unless @session.nil? || @session.profile.nil?
    if token.opaque?
      # These are going to be SSOi OAuth tokens
      profile = fetch_iam_profile(token) if profile.nil?
      populate_ssoi_oauth_token_payload(profile) unless profile.nil?
      establish_ssoi_session(profile) if @session.nil?
    else
      profile = fetch_okta_profile(token.identifiers.okta_uid) if profile.nil?
      populate_ssoi_saml_token_payload(profile) if !profile.nil? && profile.attrs['last_login_type'] == 'ssoi'
      establish_session(profile) if @session.nil?
    end
    return false if @session.nil?

    # issued for a client vs a user
    return populate_launch_context if token.ssoi_token?

    return false if @session.uuid.nil?

    @current_user = OpenidUser.find(@session.uuid)
  end

  # Populates launch context if an applicable launch scope is found
  # Returns true due to linting limitations in the authenticate_token method length
  def populate_launch_context
    populate_payload_for_launch_patient_scope if token.payload['scp'].include?('launch/patient')
    populate_payload_for_launch_scope if token.payload['scp'].include?('launch')
    true
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

  def handle_opaque_token(token_string, aud)
    opaque_token = OpaqueToken.new(token_string, aud)
    @session = Session.find(hash_token(opaque_token))
    if @session.nil?
      opaque_token.set_payload(fetch_issued(token_string))
      opaque_token.set_is_ssoi(!opaque_token.static?)
      return opaque_token if TokenUtil.validate_token(opaque_token)
    elsif @session.profile.attrs['iss'] == 'VA_SSOi_IDP'
      opaque_token.set_is_ssoi(true)
      return opaque_token
    end
    raise error_klass('Invalid token.')
  end

  def populate_ssoi_saml_token_payload(profile)
    token.payload['last_login_type'] = 'ssoi'
    token.payload['icn'] = profile.attrs['icn']
    token.payload['npi'] = profile.attrs['npi']
    token.payload['sec_id'] = profile.attrs['SecID']
    token.payload['vista_id'] = profile.attrs['VistaId']
  end

  def populate_ssoi_oauth_token_payload(profile)
    token.payload['last_login_type'] = 'ssoi'
    token.payload['icn'] = profile.attrs['icn']
    token.payload['npi'] = profile.attrs['npi']
    token.payload['sec_id'] = profile.attrs['SecID']
    token.payload['vista_id'] = profile.attrs['VistaId']
    token.payload['iat'] = profile.attrs['iat']
    token.payload['exp'] = profile.attrs['exp']
    token.payload['jti'] = profile.attrs['fediamtransactionId']
    token.payload['sub'] = profile.attrs['SecID']
    token.payload['ver'] = profile.attrs['ver']
    token.payload['cid'] = profile.attrs['cid']
    token.payload['uid'] = profile.attrs['uid']
    token.payload['scp'] = profile.attrs['scopes']
    token.payload['iss'] = profile.attrs['iss']
    token.payload['aud'] = profile.attrs['aud']
  end

  def token_from_request
    auth_request = request.authorization.to_s
    return unless auth_request[TOKEN_REGEX]

    token_string = auth_request.sub(TOKEN_REGEX, '').gsub(/^"|"$/, '')
    if jwt?(token_string)
      Token.new(token_string, fetch_aud)
    else
      # Handle opaque token
      return handle_opaque_token(token_string, fetch_aud) if Settings.oidc.issued_url

      raise error_klass('Invalid token.')
    end
  end

  def establish_session(profile)
    ttl = token.payload['exp'] - Time.current.utc.to_i

    user_identity = OpenidUserIdentity.build_from_profile(uuid: token.identifiers.uuid, profile: profile, ttl: ttl)
    @current_user = OpenidUser.build_from_identity(identity: user_identity, ttl: ttl)
    @session = build_session(ttl,
                             token.identifiers.uuid,
                             Okta::UserProfile.new({ 'last_login_type' => profile['last_login_type'],
                                                     'SecID' => profile['SecID'], 'VistaId' => profile['VistaId'],
                                                     'npi' => profile['npi'], 'icn' => profile['icn'] }))
    @session.save && user_identity.save && @current_user.save
  end

  def establish_ssoi_session(profile)
    ttl = token.payload['exp'] - Time.current.utc.to_i
    @session = build_session(ttl, profile.attrs['fediamtransactionId'], profile)
    @session.save
  end

  def token
    @token ||= token_from_request
  end

  def fetch_okta_profile(uid)
    profile_response = Okta::Service.new.user(uid)
    if profile_response.success?
      Okta::UserProfile.new(profile_response.body['profile'])
    else
      log_message_to_sentry('Error retrieving profile for OIDC token', :error,
                            body: profile_response.body)
      raise 'Unable to retrieve user profile'
    end
  end

  def fetch_iam_profile(token)
    profile_response = fetch_iam_info(token.token_string, token.payload['proxy'])
    parse_profile(profile_response)
  rescue
    log_message_to_sentry('Error retrieving IAM profile for OIDC token', :error)
    raise error_klass('Unable to retrieve IAM user profile')
  end

  def parse_profile(profile_response)
    profile = OpenStruct.new({ attrs: {} })
    profile.attrs['ver'] = 1
    profile.attrs['iss'] = profile_response['fediamissuer']
    profile.attrs['iat'] = profile_response['iat']
    profile.attrs['exp'] = profile_response['exp']
    profile.attrs['cid'] = profile_response['client_id']
    profile.attrs['uid'] = profile_response['fediamsecid']
    profile.attrs['scopes'] = profile_response['scope'].split(' ')
    profile.attrs['sub'] = profile_response['sub']
    profile.attrs['icn'] = profile_response['fediamMVIICN']
    profile.attrs['npi'] = profile_response['fediamNPI']
    profile.attrs['SecID'] = profile_response['fediamsecid']
    profile.attrs['VistaId'] = profile_response['fediamVISTAID']
    profile.attrs['fediamtransactionId'] = profile_response['fediamtransactionId']
    loa = profile_response['fediamassurLevel']
    profile.derived_loa = { current: loa, highest: loa }
    # Overwrite based on /issued response
    profile.attrs['aud'] = token.payload['aud']
    profile
  end

  def build_session(ttl, uuid, profile)
    session = Session.new(token: hash_token(token), uuid: uuid, profile: profile)
    session.expire(ttl)
    session
  end

  def build_launch_session(ttl, launch)
    session = Session.new(token: hash_token(token), launch: launch)
    session.expire(ttl)
    session
  end

  # Fetch data from various OAuth Proxy endpoints
  def fetch_smart_launch_context
    response = RestClient.get(Settings.oidc.smart_launch_url,
                              { Authorization: "Bearer #{token.token_string}" })
    raise error_klass('Invalid launch context') if response.nil?

    if response.code == 200
      json_response = JSON.parse(response.body)
      json_response['launch']
    end
  rescue => e
    log_message_to_sentry("Error retrieving smart launch context for OIDC token: #{e.message}", :error)
    raise error_klass('Invalid launch context')
  end

  def fetch_issued(token_string)
    return nil unless Settings.oidc.issued_url

    response = RestClient.get(Settings.oidc.issued_url,
                              { Authorization: "Bearer #{token_string}" })
    raise error_klass('Invalid token') if response.nil?

    if response.code == 200
      json_response = JSON.parse(response.body)
      if json_response['scopes']
        json_response['scp'] = json_response['scopes']
        json_response['scopes'] = nil
      end
      json_response
    end
  rescue => e
    raise error_klass('Invalid token') if e.to_s.include?('Unauthorized')

    raise Common::Exceptions::ServiceError('Issued service error')
  end

  def fetch_openid_configuration(proxy_url)
    return nil unless proxy_url

    response = RestClient.get("#{proxy_url}/.well-known/openid-configuration")
    raise error_klass('Invalid OpenID configuration.') if response.nil?

    JSON.parse(response.body) if response.code == 200
  rescue
    raise Common::Exceptions::ServiceError('OpenID service error')
  end

  def fetch_iam_info(token_string, proxy_url)
    return nil unless proxy_url

    openid_configuration = fetch_openid_configuration(proxy_url)
    return nil if openid_configuration['introspection_endpoint'].nil?

    client_id = fetch_opaque_client(proxy_url)
    payload = {
      token: token_string,
      token_type_hint: 'access_token'
    }
    payload['client_id'] = client_id unless client_id.nil?
    response = RestClient.post(openid_configuration['introspection_endpoint'],
                               payload,
                               { Authorization: "Bearer #{token_string}" })
    raise error_klass('Invalid token') if response.nil?

    JSON.parse(response.body) if response.code == 200
  rescue => e
    raise error_klass('Invalid token') if e.to_s.include?('Unauthorized')

    raise Common::Exceptions::ServiceError('IAM introspect service error')
  end

  # Helper methods
  def base64_json?(launch_string)
    JSON.parse(Base64.decode64(launch_string))
    true
  rescue JSON::ParserError
    false
  end

  def fetch_aud
    Settings.oidc.isolated_audience.default
  end

  def hash_token(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def jwt?(token_string)
    JWT.decode(token_string, nil, false, algorithm: 'RS256')
    true
  rescue JWT::DecodeError
    false
  end

  def fetch_opaque_client(route)
    Settings.oidc.opaque_clients.find { |opaque_client| route == opaque_client['route'] }['client_id']
  rescue
    raise error_klass('Failed opaque client lookup.')
  end

  def error_klass(error_detail_string)
    # Errors from the jwt gem (and other dependencies) are reraised with
    # this class so we can exclude them from Sentry without needing to know
    # all the classes used by our dependencies.
    Common::Exceptions::TokenValidationError.new(detail: error_detail_string)
  end

  def permit_scopes(scopes, actions: [])
    return false unless token.payload

    if (actions.empty? ||
      Array.wrap(actions).map(&:to_s).include?(action_name)) && (Array.wrap(scopes) & token.payload['scp']).empty?
      render_unauthorized
    end
  end
  attr_reader :current_user, :session, :scopes
end
