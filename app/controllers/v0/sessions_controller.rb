# frozen_string_literal: true

require 'base64'
require 'saml/url_service'

module V0
  class SessionsController < ApplicationController
    STATSD_SSO_CALLBACK_KEY = 'api.auth.saml_callback'
    STATSD_SSO_CALLBACK_TOTAL_KEY = 'api.auth.login_callback.total'
    STATSD_SSO_CALLBACK_FAILED_KEY = 'api.auth.login_callback.failed'
    STATSD_LOGIN_NEW_USER_KEY = 'api.auth.new_user'

    # Collection Action: auth is required for certain types of requests
    # @type is set automatically by the routes in config/routes.rb
    # For more details see SAML::SettingsService and SAML::URLService
    def new
      type  = params[:signup] ? 'signup' : params[:type]
      if SessionActivity::SESSION_ACTIVITY_TYPES.include?(type)
        session_activity = SessionActivity.create(
          name: type,
          originating_request_id: Thread.current['request_id'],
          originating_ip_address: request.remote_ip,
          originating_user_agent: request.user_agent,
          generated_url: url_service.send("#{type}_url")
        )

        if type == 'slo'
          Rails.logger.info('SSO: LOGOUT', sso_logging_info)
          reset_session
        end

        redirect_to session_activity.generated_url
      else
        raise Common::Exceptions::RoutingError, params[:path]
      end
    end

    def saml_logout_callback
      if session_activity.present?
        saml_response = SAML::LogoutResponse.new(params[:SAMLResponse], saml_settings, raw_get_params: params)
        if saml_response.valid?
          # ... update session activity saying its present
          # ... send Rails logs success
        else
          # ... update session activity with errors
          # ... send Rails logs failure
        end
      else
        log_message_to_sentry('SLO: No SessionActivity found.')
      end
    rescue ArgumentError => e
      log_exception_to_sentry(e)
    ensure
      redirect_to url_service.logout_redirect_url
    end

    def saml_callback
      if session_activity.present?
        saml_response = SAML::Response.new(params[:SAMLResponse], settings: saml_settings)
        @sso_service = SSOService.new(saml_response)
        if @sso_service.persist_authentication!
          @current_user = @sso_service.new_user
          @session_object = @sso_service.new_session

          set_cookies
          after_login_actions
          redirect_to saml_login_redirect_url
          stats(:success)
        else
          log_auth_too_late if @sso_service.auth_error_code == '002'
          redirect_to saml_login_redirect_url(auth: 'fail', code: @sso_service.auth_error_code)
          stats(:failure)
        end
      else
      end
    rescue NoMethodError
      log_message_to_sentry('NoMethodError', :error, base64_params_saml_response: params[:SAMLResponse])
      redirect_to saml_login_redirect_url(auth: 'fail', code: 7) unless performed?
      stats(:failed_unknown)
    ensure
      stats(:total)
    end

    private

    def authenticate
      return unless action_name == 'new'
      if %w[mfa verify slo].include?(params[:type])
        super
      else
        reset_session
      end
    end

    def session_activity
      return @session_activity if defined?(@session_activity)
      @session_activity = SessionActivity.find_by(id: session_activity_id, originating_request_id: originating_request_id)
    end

    def stats(status)
      case status
      when :success
        StatsD.increment(STATSD_LOGIN_NEW_USER_KEY) if @sso_service.new_login?
        StatsD.increment(STATSD_SSO_CALLBACK_KEY,
                         tags: ['status:success', "context:#{@sso_service.saml_response.authn_context}"])
      when :failure
        StatsD.increment(STATSD_SSO_CALLBACK_KEY,
                         tags: ['status:failure', "context:#{@sso_service.saml_response.authn_context}"])
        StatsD.increment(STATSD_SSO_CALLBACK_FAILED_KEY, tags: [@sso_service.failure_instrumentation_tag])
      when :failed_unknown
        StatsD.increment(STATSD_SSO_CALLBACK_KEY,
                         tags: ['status:failure', 'context:unknown'])
        StatsD.increment(STATSD_SSO_CALLBACK_FAILED_KEY, tags: ['error:unknown'])
      when :total
        StatsD.increment(STATSD_SSO_CALLBACK_TOTAL_KEY)
      end
    end

    def set_cookies
      Rails.logger.info('SSO: LOGIN', sso_logging_info)
      set_api_cookie!
      set_sso_cookie! # Sets a cookie "vagov_session_<env>" with attributes needed for SSO.
    end

    def saml_login_redirect_url(auth: 'success', code: nil)
      if auth == 'fail'
        url_service.login_redirect_url(auth: 'fail', code: code)
      else
        if current_user.loa[:current] < current_user.loa[:highest]
          url_service.idme_loa3_url
        else
          url_service.login_redirect_url
        end
      end
    end

    def originating_request_id
      saml_response_relay_state_params['originating_request_id']
    end

    def session_activity_id
      saml_response_relay_state_params['session_activity_id']
    end

    def saml_response_relay_state_params
      return {} unless %w[saml_callback saml_logout_callback].include?(action_name)
      @relay_state_params ||= params['RelayState'].present? ? JSON.parse(params['RelayState']) : {}
    rescue
      log_message_to_sentry('RelayState could not be parsed', :warn)
      {}
    end

    def after_login_actions
      AfterLoginJob.perform_async('user_uuid' => @current_user&.uuid)
      log_persisted_session_and_warnings
    end

    def log_persisted_session_and_warnings
      obscure_token = Session.obscure_token(@session_object.token)
      Rails.logger.info("Logged in user with id #{@session_object.uuid}, token #{obscure_token}")
      # We want to log when SSNs do not match between MVI and SAML Identity. And might take future
      # action if this appears to be happening frquently.
      if current_user.ssn_mismatch?
        additional_context = StringHelpers.heuristics(current_user.identity.ssn, current_user.va_profile.ssn)
        log_message_to_sentry('SSNS DO NOT MATCH!!', :warn, identity_compared_with_mvi: additional_context)
      end
    end

    # this method is intended to be temporary as we gather more information on the auth_too_late SAML error
    def log_auth_too_late
      session_object = Session.find(session[:token])
      user = User.find(session_object&.uuid)

      log_message_to_sentry('auth_too_late ',
                            :warn,
                            code: @sso_service.auth_error_code,
                            errors: @sso_service.errors.messages,
                            last_signed_in_if_logged_in: user&.last_signed_in,
                            authn_context: user&.authn_context)
    end

    def url_service
      SAML::URLService.new(saml_settings, session: @session_object, user: current_user)
    end
  end
end
