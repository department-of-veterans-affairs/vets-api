# frozen_string_literal: true

require 'base64'
require 'saml/url_service'
require 'saml/responses/login'
require 'saml/responses/logout'

module V0
  class SessionsController < ApplicationController
    skip_before_action :verify_authenticity_token

    REDIRECT_URLS = %w[signup mhv dslogon idme mfa verify slo].freeze

    STATSD_SSO_NEW_KEY = 'api.auth.new'
    STATSD_SSO_SAMLREQUEST_KEY = 'api.auth.saml_request'
    STATSD_SSO_SAMLRESPONSE_KEY = 'api.auth.saml_response'
    STATSD_SSO_CALLBACK_KEY = 'api.auth.saml_callback'
    STATSD_SSO_CALLBACK_TOTAL_KEY = 'api.auth.login_callback.total'
    STATSD_SSO_CALLBACK_FAILED_KEY = 'api.auth.login_callback.failed'
    STATSD_LOGIN_NEW_USER_KEY = 'api.auth.new_user'
    STATSD_LOGIN_STATUS_SUCCESS = 'api.auth.login.success'
    STATSD_LOGIN_STATUS_FAILURE = 'api.auth.login.failure'
    STATSD_LOGIN_LATENCY = 'api.auth.latency'

    VERSION_TAG = 'version:v0'

    # Collection Action: auth is required for certain types of requests
    # @type is set automatically by the routes in config/routes.rb
    # For more details see SAML::SettingsService and SAML::URLService
    def new
      type = params[:type]
      raise Common::Exceptions::RoutingError, params[:path] unless REDIRECT_URLS.include?(type)

      StatsD.increment(STATSD_SSO_NEW_KEY, tags: ["context:#{type}", VERSION_TAG])
      Rails.logger.info("SSO_NEW_KEY, tags: #{["context:#{type}", VERSION_TAG]}")
      if type == 'slo'
        url = url_service.ssoe_slo_url
        Rails.logger.info('SSO: LOGOUT', sso_logging_info)
        reset_session
      else
        url = url_service.send("#{type}_url")
        saml_request_stats
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
      saml_response_stats(saml_response)
      if saml_response.valid?
        user_login(saml_response)
      else
        log_error(saml_response)
        redirect_to url_service.login_redirect_url(auth: 'fail', code: auth_error_code(saml_response.error_code))
        callback_stats(:failure, saml_response, saml_response.error_instrumentation_code)
      end
    rescue => e
      conditional_log_exception_to_sentry(e)
      unless performed?
        redirect_to url_service.login_redirect_url(auth: 'fail',
                                                   code: SAML::Responses::Base::UNKNOWN_OR_BLANK_ERROR_CODE)
      end
      callback_stats(:failed_unknown)
    ensure
      callback_stats(:total)
    end

    private

    def conditional_log_exception_to_sentry(error)
      if (error.is_a? SAML::SAMLError) &&
         (error.code == SAML::UserAttributeError::MULTIPLE_MHV_IDS_CODE)
        # If our error is that we have multiple mhv ids, this is a case where we won't log in the user,
        # but we give them a path to resolve this. So we don't want to throw an error, and we don't want
        # to pollute Sentry with this condition, but we will still log in case we want metrics in
        # Cloudwatch or any other log aggregator
        Rails.logger.warn(
          "SessionsController version:v0 context:#{error.context} "\
          "message:#{error.message}"
        )
      else
        log_exception_to_sentry(error, {}, {}, :error)
      end
    end

    def auth_error_code(code)
      if code == SAML::Responses::Base::AUTH_TOO_LATE_ERROR_CODE && validate_session
        UserSessionForm::ERRORS[:saml_replay_valid_session][:code]
      else
        code
      end
    end

    def authenticate
      return unless action_name == 'new'

      if %w[mfa verify].include?(params[:type])
        super
      elsif params[:type] == 'slo'
        # load the session object and current user before attempting to destroy
        load_user
        reset_session
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
        if location.start_with?(url_service.base_redirect_url)
          # only record login stats if the user is being redirect to the site
          # some users will need to be up-leveled and this will be redirected
          # back to the identity provider
          login_stats(:success, saml_response, user_session_form)
        else
          saml_request_stats
          callback_stats(:success, saml_response)
        end
      else
        log_message_to_sentry(
          user_session_form.errors_message, user_session_form.errors_hash[:level], user_session_form.errors_context
        )
        redirect_to url_service.login_redirect_url(auth: 'fail', code: user_session_form.error_code)
        login_stats(:failure, saml_response, user_session_form)
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

    def saml_request_stats
      tracker = url_service.tracker
      values = {
        'id' => tracker&.uuid,
        'authn' => tracker&.payload_attr(:authn_context),
        'type' => tracker&.payload_attr(:type)
      }
      Rails.logger.info("ID.me: SAML Request => #{values}")
      StatsD.increment(STATSD_SSO_SAMLREQUEST_KEY,
                       tags: ["type:#{tracker&.payload_attr(:type)}",
                              "context:#{tracker&.payload_attr(:authn_context)}",
                              VERSION_TAG])
    end

    def saml_response_stats(saml_response)
      type = html_escaped_relay_state['type']
      values = {
        'id' => saml_response.in_response_to,
        'authn' => saml_response.authn_context,
        'type' => type
      }
      Rails.logger.info("ID.me: SAML Response => #{values}")
      StatsD.increment(STATSD_SSO_SAMLRESPONSE_KEY,
                       tags: ["type:#{type}",
                              "context:#{saml_response.authn_context}",
                              VERSION_TAG])
    end

    def login_stats_success(saml_response)
      type = url_service.tracker.payload_attr(:type)
      tags = ["context:#{type}", VERSION_TAG]
      StatsD.increment(STATSD_LOGIN_NEW_USER_KEY, tags: [VERSION_TAG]) if type == 'signup'
      StatsD.increment(STATSD_LOGIN_STATUS_SUCCESS, tags: tags)
      Rails.logger.info("LOGIN_STATUS_SUCCESS, tags: #{tags}")
      StatsD.measure(STATSD_LOGIN_LATENCY, url_service.tracker.age, tags: tags)
      callback_stats(:success, saml_response)
    end

    def login_stats(status, saml_response, user_session_form)
      case status
      when :success
        login_stats_success(saml_response)
      when :failure
        tags = ["context:#{url_service.tracker.payload_attr(:type)}", VERSION_TAG]
        StatsD.increment(STATSD_LOGIN_STATUS_FAILURE, tags: tags)
        Rails.logger.info("LOGIN_STATUS_FAILURE, tags: #{tags}")
        callback_stats(:failure, saml_response, user_session_form.error_instrumentation_code)
      end
    end

    def callback_stats(status, saml_response = nil, failure_tag = nil)
      case status
      when :success
        StatsD.increment(STATSD_SSO_CALLBACK_KEY,
                         tags: ['status:success',
                                "context:#{saml_response.authn_context}",
                                VERSION_TAG])
        # track users who have a shared sso cookie
      when :failure
        StatsD.increment(STATSD_SSO_CALLBACK_KEY,
                         tags: ['status:failure',
                                "context:#{saml_response.authn_context}",
                                VERSION_TAG])
        StatsD.increment(STATSD_SSO_CALLBACK_FAILED_KEY, tags: [failure_tag, VERSION_TAG])
      when :failed_unknown
        StatsD.increment(STATSD_SSO_CALLBACK_KEY,
                         tags: ['status:failure', 'context:unknown', VERSION_TAG])
        StatsD.increment(STATSD_SSO_CALLBACK_FAILED_KEY, tags: ['error:unknown', VERSION_TAG])
      when :total
        StatsD.increment(STATSD_SSO_CALLBACK_TOTAL_KEY, tags: [VERSION_TAG])
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
      Rails.logger.info("Logged in user with id #{@session_object&.uuid}, token #{obscure_token}")
      # We want to log when SSNs do not match between MVI and SAML Identity. And might take future
      # action if this appears to be happening frequently.
      if current_user.ssn_mismatch?
        additional_context = StringHelpers.heuristics(current_user.identity.ssn, current_user.ssn_mpi)
        log_message_to_sentry(
          'SessionsController version:v0 message:SSN from MPI Lookup does not match UserIdentity cache',
          :warn,
          identity_compared_with_mpi: additional_context
        )
      end
    end

    def html_escaped_relay_state
      JSON.parse(CGI.unescapeHTML(params[:RelayState] || '{}'))
    end

    def originating_request_id
      html_escaped_relay_state['originating_request_id']
    rescue
      'UNKNOWN'
    end

    def url_service
      @url_service ||= SAML::URLService.new(saml_settings,
                                            session: @session_object,
                                            user: current_user,
                                            params: params)
    end
  end
end
