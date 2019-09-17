# frozen_string_literal: true

require 'base64'
require 'saml/url_service'
require 'saml/responses/login'
require 'saml/responses/logout'

module V0
  class SessionsController < ApplicationController
    REDIRECT_URLS = %w[signup mhv dslogon idme mfa verify slo].freeze

    STATSD_SSO_NEW_KEY = 'api.auth.new'
    STATSD_SSO_CALLBACK_KEY = 'api.auth.saml_callback'
    STATSD_SSO_CALLBACK_TOTAL_KEY = 'api.auth.login_callback.total'
    STATSD_SSO_CALLBACK_FAILED_KEY = 'api.auth.login_callback.failed'
    STATSD_LOGIN_NEW_USER_KEY = 'api.auth.new_user'

    # Collection Action: auth is required for certain types of requests
    # @type is set automatically by the routes in config/routes.rb
    # For more details see SAML::SettingsService and SAML::URLService
    def new
      type = params[:type]
      raise Common::Exceptions::RoutingError, params[:path] unless REDIRECT_URLS.include?(type)
      StatsD.increment(STATSD_SSO_NEW_KEY, tags: ["context:#{type}"])
      url = url_service.send("#{type}_url")
      if type == 'slo'
        Rails.logger.info('SSO: LOGOUT', sso_logging_info)
        reset_session
      end
      # clientId must be added at the end or the URL will be invalid for users using various "Do not track"
      # extensions with their browser.
      redirect_to params[:client_id].present? ? url + "&clientId=#{params[:client_id]}" : url
    end

    def saml_logout_callback
      saml_response = SAML::Responses::Logout.new(params[:SAMLResponse], saml_settings, raw_get_params: params)
      Raven.extra_context(in_response_to: saml_response.try(:in_response_to) || 'ERROR')

      if saml_response.valid?
        user_logout(saml_response)
      else
        log_error(saml_response)
        Rails.logger.info("SLO callback response invalid for originating_request_id '#{originating_request_id}'")
      end
    rescue => e
      log_exception_to_sentry(e, {}, {}, :error)
    ensure
      redirect_to url_service.logout_redirect_url
    end

    def saml_callback
      saml_response = SAML::Responses::Login.new(params[:SAMLResponse], settings: saml_settings)

      if saml_response.valid?
        user_login(saml_response)
      else
        log_error(saml_response)
        redirect_to url_service.login_redirect_url(auth: 'fail', code: auth_error_code(saml_response.error_code))
        stats(:failure, saml_response, saml_response.error_instrumentation_code)
      end
    rescue => e
      log_exception_to_sentry(e, {}, {}, :error)
      redirect_to url_service.login_redirect_url(auth: 'fail', code: '007') unless performed?
      stats(:failed_unknown)
    ensure
      stats(:total)
    end

    private

    def auth_error_code(code)
      if code == '005' && validate_session
        UserSessionForm::ERRORS[:saml_replay_valid_session][:code]
      else
        code
      end
    end

    def authenticate
      return unless action_name == 'new'
      if %w[mfa verify slo].include?(params[:type])
        super
      else
        reset_session
      end
    end

    def log_error(saml_response)
      log_message_to_sentry(saml_response.errors_message,
                            saml_response.errors_hash[:level],
                            saml_error_context: saml_response.errors_context)
    end

    def user_login(saml_response)
      user_session_form = UserSessionForm.new(saml_response)
      if user_session_form.valid?
        @current_user, @session_object = user_session_form.persist
        set_cookies
        after_login_actions
        redirect_to url_service.login_redirect_url
        stats(:success, saml_response)
      else
        log_message_to_sentry(
          user_session_form.errors_message, user_session_form.errors_hash[:level], user_session_form.errors_context
        )
        redirect_to url_service.login_redirect_url(auth: 'fail', code: user_session_form.error_code)
        stats(:failure, saml_response, user_session_form.error_instrumentation_code)
      end
    end

    def user_logout(saml_response)
      logout_request = SingleLogoutRequest.find(saml_response&.in_response_to)
      if logout_request.present?
        logout_request.destroy
        Rails.logger.info("SLO callback response to '#{saml_response&.in_response_to}' for originating_request_id "\
          "'#{originating_request_id}'")
      else
        Rails.logger.info('SLO callback response could not resolve logout request for originating_request_id '\
          "'#{originating_request_id}'")
      end
    end

    def stats(status, saml_response = nil, failure_tag = nil)
      case status
      when :success
        StatsD.increment(STATSD_LOGIN_NEW_USER_KEY) if request_type == 'signup'
        StatsD.increment(STATSD_SSO_CALLBACK_KEY,
                         tags: ['status:success', "context:#{saml_response.authn_context}"])
      when :failure
        StatsD.increment(STATSD_SSO_CALLBACK_KEY,
                         tags: ['status:failure', "context:#{saml_response.authn_context}"])
        StatsD.increment(STATSD_SSO_CALLBACK_FAILED_KEY, tags: [failure_tag])
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

    def originating_request_id
      JSON.parse(params[:RelayState] || '{}')['originating_request_id']
    rescue
      'UNKNOWN'
    end

    def request_type
      JSON.parse(params[:RelayState] || '{}')['type']
    rescue
      'UNKNOWN'
    end

    def url_service
      SAML::URLService.new(saml_settings, session: @session_object, user: current_user, params: params)
    end
  end
end
