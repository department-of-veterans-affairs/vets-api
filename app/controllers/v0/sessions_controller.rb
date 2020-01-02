# frozen_string_literal: true

require 'base64'
require 'saml/url_service'
require 'saml/responses/login'
require 'saml/responses/logout'

module V0
  class SessionsController < ApplicationController
    before_action :set_extra_context, only: %i[saml_callback saml_logout_callback]

    STATSD_SSO_NEW_KEY = 'api.auth.new'
    STATSD_SSO_CALLBACK_KEY = 'api.auth.saml_callback'
    STATSD_SSO_CALLBACK_TOTAL_KEY = 'api.auth.login_callback.total'
    STATSD_SSO_CALLBACK_FAILED_KEY = 'api.auth.login_callback.failed'
    STATSD_LOGIN_NEW_USER_KEY = 'api.auth.new_user'
    UNKNOWN_RELAYSTATE_ATTR = 'UNKNOWN'
    STATSD_MHV_COOKIE_NO_ACCOUNT_KEY = 'api.auth.mhv_cookie.no_user'

    # Collection Action: auth is required for certain types of requests
    # @type is set automatically by the routes in config/routes.rb
    # For more details see SAML::SettingsService and SAML::URLService
    def new
      type = params[:type]

      unless SessionActivity::SESSION_ACTIVITY_TYPES.include?(type)
        raise Common::Exceptions::RoutingError, params[:path]
      end

      raise Common::Exceptions::RoutingError, params[:path] unless REDIRECT_URLS.include?(type)

      StatsD.increment(STATSD_SSO_NEW_KEY, tags: ["context:#{type}"])
      url = url_service.send("#{type}_url")

      SessionActivity.create!(
        sa_metadata.merge(
          name: type,
          generated_url: url
        )
      )

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
        session_activity&.update_success(sa_metadata)
      else
        log_error(saml_response)
        Rails.logger.info("SLO callback response invalid for originating_request_id '#{originating_request_id}'")
        session_activity&.update_fail(sa_metadata)
      end
    rescue => e
      log_exception_to_sentry(e, {}, {}, :error)
    ensure
      redirect_to url_service.logout_redirect_url
    end

    def saml_callback
      raise Common::Exceptions::RoutingError, params[:path] if session_activity.blank?

      saml_response = SAML::Responses::Login.new(params[:SAMLResponse], settings: saml_settings)

      if saml_response.valid?
        user_login(saml_response)
        session_activity.update_success(sa_metadata)
      else
        log_error(saml_response)
        redirect_to url_service.login_redirect_url(auth: 'fail', code: auth_error_code(saml_response.error_code))
        stats(:failure, saml_response, saml_response.error_instrumentation_code)
        session_activity.update_fail(sa_metadata)
      end
    rescue => e
      log_exception_to_sentry(e, {}, {}, :error)
      redirect_to url_service.login_redirect_url(auth: 'fail', code: '007') unless performed?
      stats(:failed_unknown)
    ensure
      stats(:total)
    end

    private

    def sa_metadata
      {
        originating_request_id: Thread.current['request_id'],
        originating_ip_address: request.remote_ip,
        additional_data: { originating_user_agent: request.user_agent }
      }
    end

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

    def session_activity
      return @session_activity if defined?(@session_activity)

      @session_activity = SessionActivity.find_by(
        id: session_activity_id,
        originating_request_id: originating_request_id
      )
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
        # track users who need to re-login on MHV
        StatsD.increment(STATSD_MHV_COOKIE_NO_ACCOUNT_KEY) unless @current_user.mhv_correlation_id
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

    def get_relaystate_attr(attr)
      @relay_state ||=
        begin
          JSON.parse(params[:RelayState])
        rescue
          {}
        end

      @relay_state[attr] || UNKNOWN_RELAYSTATE_ATTR
    end

    def session_activity_id
      get_relaystate_attr('session_activity_id')
    end

    def originating_request_id
      get_relaystate_attr('originating_request_id')
    end

    def request_type
      get_relaystate_attr('type')
    end

    def set_extra_context
      Raven.extra_context(
        RelayState: params[:RelayState],
        session_activity_id: session_activity_id,
        originating_request_id: originating_request_id,
        request_type: request_type,
        session_activity: session_activity&.attributes
      )
    end

    def url_service
      SAML::URLService.new(saml_settings, session: @session_object, user: current_user, params: params)
    end
  end
end
