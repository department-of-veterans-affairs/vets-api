# frozen_string_literal: true

module Mobile
  class ApplicationController < BaseApplicationController
    before_action :check_feature_flag, :authenticate
    skip_before_action :authenticate, only: %i[cors_preflight routing_error]

    ACCESS_TOKEN_REGEX = /^Bearer /.freeze

    def cors_preflight
      head(:ok)
    end

    private

    def check_feature_flag
      return nil if Flipper.enabled?(:mobile_api)

      message = {
        errors: [
          {
            title: 'Not found',
            detail: 'There are no routes matching your request',
            code: '411',
            status: '404'
          }
        ]
      }

      render json: message, status: :not_found
    end

    def authenticate
      raise_forbidden('Missing Authorization header') if request.headers['Authorization'].nil?
      raise_forbidden('Authorization header Bearer token is blank') if access_token.blank?

      session = IAMSession.find(access_token)

      if session
        @current_user = IAMUser.find(session.uuid)
      else
        create_iam_session
      end
    end

    def access_token
      @access_token ||= request.headers['Authorization'].gsub(ACCESS_TOKEN_REGEX, '')
    end

    def create_iam_session
      iam_profile = iam_ssoe_service.post_introspect(access_token)
      user_identity = build_identity(iam_profile)
      build_user(user_identity)
      build_session(user_identity)
    rescue Common::Exceptions::Forbidden => e
      StatsD.increment('mobile.application_controller.create_iam_session.inactive_session')
      raise e
    end

    def build_identity(iam_profile)
      user_identity = IAMUserIdentity.build_from_iam_profile(iam_profile)
      user_identity.save
      user_identity
    end

    def build_session(user_identity)
      session = IAMSession.new(token: access_token, uuid: user_identity.uuid)
      session.save
    end

    def build_user(user_identity)
      @current_user = IAMUser.build_from_user_identity(user_identity)
      @current_user.save
    end

    def iam_ssoe_service
      IAMSSOeOAuth::Service.new
    end

    def raise_forbidden(detail)
      raise Common::Exceptions::Forbidden.new(detail: detail)
    end
  end
end
