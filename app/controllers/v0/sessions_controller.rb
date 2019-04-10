# frozen_string_literal: true

require 'base64'
require 'saml/url_service'

module V0
  class SessionsController < ApplicationController
    REDIRECT_URLS = %w[signup mhv dslogon idme mfa verify slo].freeze

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
      url = url_service.send("#{type}_url")
      if type == 'slo'
        Rails.logger.info('SSO: LOGOUT', sso_logging_info)
        reset_session
      end
      redirect_to url
    end

    def saml_logout_callback
      logout_response = OneLogin::RubySaml::Logoutresponse.new(params[:SAMLResponse], saml_settings,
                                                               raw_get_params: params)
      logout_request  = SingleLogoutRequest.find(logout_response&.in_response_to)

      errors = build_logout_errors(logout_response, logout_request)

      if errors.size.positive?
        extra_context = { in_response_to: logout_response&.in_response_to }
        log_message_to_sentry("SAML Logout failed!\n  " + errors.join("\n  "), :error, extra_context)
      end
    rescue => e
      log_exception_to_sentry(e, {}, {}, :error)
    ensure
      logout_request&.destroy
      redirect_to url_service.logout_redirect_url
    end

    def saml_callback
      saml_response = SAML::Response.new(params[:SAMLResponse], settings: saml_settings)
      if saml_response.valid?
        user_session_form = UserSessionForm.new(saml_response)
        if user_session_form.valid?
          @current_user, @session_object = user_session_form.persist
          set_cookies
          after_login_actions
          redirect_to url_service.login_redirect_url
          stats(:success)
        else
          log_auth_too_late if @sso_service.auth_error_code == '002'
          redirect_to url_service.login_redirect_url(auth: 'fail', code: @sso_service.auth_error_code)
          stats(:failure)
        end
      else
      end
    rescue NoMethodError => e
      log_message_to_sentry('NoMethodError', :error, full_message: e.message)
      redirect_to url_service.login_redirect_url(auth: 'fail', code: '007') unless performed?
      stats(:failed_unknown)
    ensure
      stats(:total)
    end

    private

    def persist_authentication()
      errors = []
      errors.add(:new_session, :invalid) unless new_session.valid?
      errors.add(:new_user, :invalid) unless new_user.valid?
      errors.add(:new_user_identity, :invalid) unless new_user_identity.valid?
    end

    def authenticate
      return unless action_name == 'new'
      if %w[mfa verify slo].include?(params[:type])
        super
      else
        reset_session
      end
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

    def build_logout_errors(logout_response, logout_request)
      errors = []
      errors.concat(logout_response.errors) unless logout_response.validate(true)
      errors << 'inResponseTo attribute is nil!' if logout_response&.in_response_to.nil?
      errors << 'Logout Request not found!' if logout_request.nil?
      errors
    end

    def handle_error_reporting_and_instrumentation
      message = 'Login Fail! '
      if saml_response.normalized_errors.present?
        error_hash = saml_response.normalized_errors.first
        error_context = saml_response.normalized_errors
        message += error_hash[:short_message]
        message += ' Multiple SAML Errors' if saml_response.normalized_errors.count > 1
      else
        error_hash = ERRORS[:validations_failed]
        error_context = validation_error_context
        message += error_hash[:short_message]
      end
      @auth_error_code = error_hash[:code]
      @failure_instrumentation_tag = "error:#{error_hash[:tag]}"
      log_message_to_sentry(message, error_hash[:level], error_context)
    end

    def validation_error_context
      {
        uuid: new_user.uuid,
        user:   {
          valid: new_user&.valid?,
          errors: new_user&.errors&.full_messages
        },
        session:   {
          valid: new_session&.valid?,
          errors: new_session&.errors&.full_messages
        },
        identity: {
          valid: new_user_identity&.valid?,
          errors: new_user_identity&.errors&.full_messages,
          authn_context: new_user_identity&.authn_context,
          loa: new_user_identity&.loa
        }
      }
    end

    def url_service
      SAML::URLService.new(saml_settings, session: @session_object, user: current_user, params: params)
    end
  end
end
