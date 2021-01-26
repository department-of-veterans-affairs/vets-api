# frozen_string_literal: true

module OAuthConcerns
  extend ActiveSupport::Concern

  protected

  def authenticate
    authenticate_token || render_unauthorized
  end

  def authenticate_token
    return false if token.blank?

    # issued for a client vs a user
    if token.client_credentials_token?
      token.payload[:icn] = fetch_smart_launch_context if token.payload['scp'].include?('launch/patient')
      return true
    end

    @session = Session.find(token)
    establish_session if @session.nil?
    return false if @session.nil?

    @current_user = OpenidUser.find(@session.uuid)
  end

  def fetch_aud
    Settings.oidc.isolated_audience.default
  end

  def establish_session
    ttl = token.payload['exp'] - Time.current.utc.to_i
    profile = fetch_profile(token.identifiers.okta_uid)
    user_identity = OpenidUserIdentity.build_from_okta_profile(uuid: token.identifiers.uuid, profile: profile, ttl: ttl)
    @current_user = OpenidUser.build_from_identity(identity: user_identity, ttl: ttl)
    @session = build_session(ttl)
    @session.save && user_identity.save && @current_user.save
  end

  def build_session(ttl)
    session = Session.new(token: token.to_s, uuid: token.identifiers.uuid)
    session.expire(ttl)
    session
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

  def permit_scopes(scopes, actions: [])
    return false unless token.payload

    if actions.empty? || Array.wrap(actions).map(&:to_s).include?(action_name)
      render_unauthorized if (Array.wrap(scopes) & token.payload['scp']).empty?
    end
  end
end
