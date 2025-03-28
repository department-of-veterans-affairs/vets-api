# frozen_string_literal: true

module Mobile
  class ApplicationController < SignIn::ApplicationController
    include Traceable
    include SignIn::AudienceValidator

    service_tag 'mobile-app'
    validates_access_token_audience IdentitySettings.sign_in.vamobile_client_id

    before_action :authenticate
    before_action :set_sentry_tags_and_extra_context
    skip_before_action :authenticate, only: :cors_preflight

    private

    attr_reader :current_user

    def authenticate
      return super if sis_authentication?

      StatsD.increment('iam_ssoe_oauth.auth.total')
      raise_unauthorized('Missing Authorization header') if request.headers['Authorization'].nil?
      raise_unauthorized('Authorization header Bearer token is blank') if access_token.blank?

      session_manager = IAMSSOeOAuth::SessionManager.new(access_token)
      @current_user = session_manager.find_or_create_user
      StatsD.increment('iam_ssoe_oauth.auth.success')
      @current_user
    end

    def sis_authentication?
      request.headers['Authentication-Method'] == 'SIS'
    end

    def access_token
      return super if sis_authentication?

      @access_token ||= bearer_token
    end

    def raise_unauthorized(detail)
      raise Common::Exceptions::Unauthorized.new(detail:)
    end

    def session
      return super if sis_authentication?

      Session.obscure_token(access_token)
    end

    def set_sentry_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'mobile' }
      Sentry.set_tags(source: 'mobile')
    end
  end
end
