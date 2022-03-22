# frozen_string_literal: true

require 'iam_ssoe_oauth/service'

module IAMSSOeOAuth
  class SessionManager
    STATSD_OAUTH_SESSION_KEY = 'iam_ssoe_oauth.session'

    def initialize(access_token)
      @access_token = access_token
      @session = IAMSession.find(access_token)
    end

    def find_or_create_user
      return IAMUser.find(@session.uuid) if @session

      create_user_session
    end

    def logout
      uuid = @session.uuid
      Rails.logger.info('IAMUser logout: start', uuid: uuid)

      identity_destroy_count = IAMUserIdentity.find(uuid).destroy
      user_destroy_count = IAMUser.find(uuid).destroy
      session_destroy_count = @session.destroy

      # redis returns number of records successfully deleted
      if [identity_destroy_count, user_destroy_count, session_destroy_count].all?(&:positive?)
        Rails.logger.info('IAMUser logout: success', uuid: uuid)
        true
      else
        Rails.logger.warn('IAMUser logout: failure', uuid: uuid, status: {
                            identity_destroy_count: identity_destroy_count,
                            user_destroy_count: user_destroy_count,
                            session_destroy_count: session_destroy_count
                          })
        false
      end
    end

    private

    def create_user_session
      Rails.logger.info('IAMUser create_user_session: start')

      iam_profile = iam_ssoe_service.post_introspect(@access_token)
      Rails.logger.info('IAMUser create_user_session: introspect succeeded')
      Rails.logger.info('IAMUser Introspect Response:', response: iam_profile)
      Rails.logger.info('IAMUser create_user_session: login type', login_type: iam_profile[:fediamauth_n_type])

      user_identity = build_identity(iam_profile)
      session = build_session(@access_token, user_identity)
      user = build_user(user_identity)
      handle_nil_user(user_identity) if user.nil?
      validate_user(user)
      log_session_info(iam_profile, user_identity, @access_token)
      persist(session, user)
    rescue Common::Exceptions::Unauthorized => e
      Rails.logger.error('IAMUser create user session: unauthorized', error: e.message)
      StatsD.increment('iam_ssoe_oauth.inactive_session')
      raise e
    end

    def build_identity(iam_profile)
      user_identity = IAMUserIdentity.build_from_iam_profile(iam_profile)
      user_identity.save
      user_identity
    rescue => e
      Rails.logger.error('IAMUser create user session: build identity failed', error: e.message)
      raise e
    end

    def build_session(access_token, user_identity)
      @session = IAMSession.new(token: access_token, uuid: user_identity.uuid)
    rescue => e
      Rails.logger.error('IAMUser create user session: build session failed', error: e.message)
      raise e
    end

    def build_user(user_identity)
      user = IAMUser.build_from_user_identity(user_identity)
      user.last_signed_in = Time.now.utc

      StatsD.set('iam_ssoe_oauth.users', user.uuid, sample_rate: 1.0)
      Rails.logger.info('IAMUser create user session: success', uuid: user.uuid)

      user
    rescue => e
      Rails.logger.error('IAMUser create user session: build user failed', error: e.message)
      raise e
    end

    def persist(session, user)
      session.save && user.save
      user
    end

    def validate_user(user)
      raise Common::Exceptions::Unauthorized, detail: 'User record global deny flag' if user.id_theft_flag
    end

    def iam_ssoe_service
      IAMSSOeOAuth::Service.new
    end

    def log_session_info(iam_profile, identity, token)
      session_type = (newly_authenticated?(iam_profile) ? 'new' : 'refresh')
      credential_type = iam_profile[:fediamauth_n_type]
      log_attrs = {
        user_uuid: identity.uuid,
        secid: identity.iam_sec_id,
        token: Session.obscure_token(token),
        credential_type: credential_type,
        session_type: session_type
      }
      Rails.logger.info('IAM SSOe OAuth: Session established', log_attrs)
      StatsD.increment(STATSD_OAUTH_SESSION_KEY, tags: ["type:#{session_type}", "credential:#{credential_type}"])
    end

    def newly_authenticated?(iam_profile)
      auth_instant = DateTime.strptime(iam_profile[:fediam_authentication_instant])
      token_instant = Time.at(iam_profile[:iat]).utc.to_datetime
      auth_instant + 10.minutes > token_instant
    rescue => e
      Rails.logger.error("IAM SSOe OAuth: Error parsing token time: #{e.message}")
      false
    end

    def handle_nil_user(user_identity)
      Rails.logger.error('IAMSSOeOAuth::SessionManager built a nil user',
                         sign_in_method: user_identity&.sign_in, user_identity_icn: user_identity&.icn)
      raise Common::Exceptions::Unauthorized, detail: 'User is nil'
    end
  end
end
