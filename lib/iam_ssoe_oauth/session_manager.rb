# frozen_string_literal: true

require 'iam_ssoe_oauth/service'

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
    
    def logout
      response = iam_ssoe_service.post_revoke(@access_token)
      destroy_user_session if response.status == 200
    end

    private

    def destroy_user_session
      uuid = @session.uuid
      identity_destroy_result = IAMUserIdentity.find(uuid).destroy
      user_destroy_result = IAMUser.find(uuid).destroy
      session_destroy_result = @session.destroy
      
      if [identity_destroy_result, user_destroy_result, session_destroy_result].all? true
        Rails.logger.info('IAMUser log out success', uuid: uuid)
        true
      else
        Rails.logger.warn('IAMUser log out failure', uuid: uuid, status: {
          identity_destroy_result: identity_destroy_result,
          user_destroy_result: user_destroy_result,
          session_destroy_result: session_destroy_result
        })
        false
      end
    end

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
