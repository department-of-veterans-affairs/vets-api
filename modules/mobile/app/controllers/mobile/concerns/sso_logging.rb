# frozen_string_literal: true

module Mobile::Concerns::SSOLogging
  extend ActiveSupport::Concern

  included do
    after_action do
      next unless %w[create update destroy].include?(action_name)

      log_sso_info
    end

    def log_sso_info
      action = request.controller_instance.controller_path.classify.to_s
      action += 'Controller#'
      action += request.parameters['action'].to_s

      Rails.logger.warn(
        "#{action} request completed", sso_logging_info
      )
    end

    def sso_logging_info
      { user_uuid: @current_user&.uuid,
        sso_cookie_contents: sso_cookie_content,
        request_host: request.host }
    end

    def sso_cookie_content
      return nil if @current_user.blank?

      { 'patientIcn' => @current_user.icn,
        'signIn' => @current_user.identity.sign_in.deep_transform_keys { |key| key.to_s.camelize(:lower) },
        'credential_used' => @current_user.identity.sign_in[:service_name],
        'credential_uuid' => credential_uuid,
        'expirationTime' => if sis_authentication?
                              sign_in_expiration_time
                            else
                              @current_user.identity.expiration_timestamp
                            end }
    end

    def credential_uuid
      case @current_user.identity.sign_in[:service_name]
      when SAML::User::IDME_CSID
        @current_user.identity.idme_uuid
      when SAML::User::LOGINGOV_CSID
        @current_user.identity.logingov_uuid
      end
    end

    def sign_in_expiration_time
      if sis_authentication?
        if sign_in_service_session
          sign_in_service_session.refresh_expiration.iso8601(0)
        else
          @session_object.ttl_in_time.iso8601(0)
        end
      else
        @current_user.identity.expiration_timestamp
      end
    end

    def sign_in_service_session
      return unless @access_token

      @sign_in_service_session ||= SignIn::OAuthSession.find_by(handle: @access_token.session_handle)
    end
  end
end
