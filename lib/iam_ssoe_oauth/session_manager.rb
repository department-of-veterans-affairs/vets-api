# frozen_string_literal: true

module IAMSSOeOAuth
  class SessionManager
    def initialize(access_token)
      @access_token = access_token
      @session = IAMSession.find(access_token)
    end

    def find_or_create_user
      return IAMUser.find(@session.uuid) if @session

      create_user_session
    end

    private

    def create_user_session
      iam_profile = iam_ssoe_service.post_introspect(@access_token)
      user_identity = build_identity(iam_profile)
      build_session(@access_token, user_identity)
      build_user(user_identity)
    rescue Common::Exceptions::Unauthorized => e
      StatsD.increment('iam_ssoe_oauth.inactive_session')
      raise e
    end

    def build_identity(iam_profile)
      user_identity = IAMUserIdentity.build_from_iam_profile(iam_profile)
      user_identity.save
      user_identity
    end

    def build_session(access_token, user_identity)
      session = IAMSession.new(token: access_token, uuid: user_identity.uuid)
      session.save
    end

    def build_user(user_identity)
      user = IAMUser.build_from_user_identity(user_identity)
      user.save
      user
    end

    def iam_ssoe_service
      IAMSSOeOAuth::Service.new
    end
  end
end
