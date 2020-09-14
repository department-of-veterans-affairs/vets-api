# frozen_string_literal: true

module Mobile
  class ApplicationController < BaseApplicationController
    before_action :check_feature_flag, :authenticate
    skip_before_action :authenticate, only: %i[cors_preflight routing_error]

    ACCESS_TOKEN_REGEX = /^Bearer /.freeze

    def cors_preflight
      head(:ok)
    end

    def routing_error
      raise Common::Exceptions::RoutingError, params[:path]
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
      raise Common::Exceptions::Forbidden.new(detail: 'Missing bearer auth token') if access_token.nil?

      @session = IAMSession.find(access_token)

      if @session
        @current_user = IAMUser.find(@session.uuid)
      else
        create_iam_session
      end
    end

    def access_token
      header = request.headers['Authorization']
      @access_token ||= header.gsub(ACCESS_TOKEN_REGEX, '')
    end

    def create_iam_session
      iam_profile = iam_ssoe_service.post_introspect(access_token)
      user_identity = build_identity(iam_profile)
      build_user(user_identity)
      build_session(user_identity)
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
  end
end
