# frozen_string_literal: true

require 'base64'
require 'saml/url_service'
require 'saml/responses/login'
require 'saml/responses/logout'

module V1
  class SessionsController < ApplicationController
    skip_before_action :verify_authenticity_token

    REDIRECT_URLS = %w[signup mhv dslogon idme mfa verify slo].freeze

    STATSD_SSO_NEW_KEY = 'api.auth.new'
    STATSD_SSO_NEW_FORCEAUTH = 'api.auth.new.forceauth'
    STATSD_SSO_NEW_INBOUND = 'api.auth.new.inbound'
    STATSD_SSO_CALLBACK_KEY = 'api.auth.saml_callback'
    STATSD_SSO_CALLBACK_TOTAL_KEY = 'api.auth.login_callback.total'
    STATSD_SSO_CALLBACK_FAILED_KEY = 'api.auth.login_callback.failed'
    STATSD_LOGIN_NEW_USER_KEY = 'api.auth.new_user'
    STATSD_LOGIN_STATUS = 'api.auth.login'
    STATSD_LOGIN_SHARED_COOKIE = 'api.auth.sso_shared_cookie'
    STATSD_LOGIN_LATENCY = 'api.auth.latency'

    VERSION_TAG = 'version:v1'

    # Collection Action: auth is required for certain types of requests
    # @type is set automatically by the routes in config/routes.rb
    # For more details see SAML::SettingsService and SAML::URLService
    def new
      type = params[:type]
      raise Common::Exceptions::RoutingError, params[:path] unless REDIRECT_URLS.include?(type)

      new_stats(type)
      url = redirect_url(type)

      if type == 'slo'
        Rails.logger.info("LOGOUT of type #{type}", sso_logging_info)
        reset_session
      end
      # clientId must be added at the end or the URL will be invalid for users using various "Do not track"
      # extensions with their browser.
      redirect_to params[:client_id].present? ? url + "&clientId=#{params[:client_id]}" : url
    end

    def ssoe_slo_callback
      redirect_to url_service.logout_redirect_url
    end

    def saml_callback
      saml_response = SAML::Responses::Login.new(params[:SAMLResponse], settings: saml_settings)
      if saml_response.valid?
        user_login(saml_response)
      else
        log_error(saml_response)
        redirect_to url_service.login_redirect_url(auth: 'fail', code: auth_error_code(saml_response.error_code))
        callback_stats(:failure, saml_response, saml_response.error_instrumentation_code)
      end
    rescue SAML::UserAttributeError => e
      log_message_to_sentry(e.message, :warning)
      redirect_to url_service.login_redirect_url(auth: 'fail', code: e.code)
      callback_stats(:failure, saml_response, e.tag)
    rescue => e
      log_exception_to_sentry(e, {}, {}, :error)
      redirect_to url_service.login_redirect_url(auth: 'fail', code: '007') unless performed?
      callback_stats(:failed_unknown)
    ensure
      callback_stats(:total)
    end

    def metadata
      meta = OneLogin::RubySaml::Metadata.new
      render xml: meta.generate(saml_settings), content_type: 'application/xml'
    end

    private

    # rubocop:disable Metrics/CyclomaticComplexity
    def redirect_url(type)
      case type
      when 'signup'
        url_service.signup_url
      when 'mhv'
        url_service.mhv_url
      when 'dslogon'
        url_service.dslogon_url
      when 'idme'
        url_service.idme_url
      when 'mfa'
        url_service.mfa_url
      when 'verify'
        url_service.verify_url
      when 'slo'
        url_service.ssoe_slo_url # due to shared url service implementation
      else
        raise Common::Exceptions::RoutingError, params[:path]
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def force_authn?
      params[:force]&.downcase == 'true'
    end

    def inbound_ssoe?
      params[:inbound]&.downcase == 'true'
    end

    def saml_settings(options = {})
      # add a forceAuthn value to the saml settings based on the initial options or
      # the "force" value in the query params
      options[:force_authn] ||= force_authn?
      SAML::SSOeSettingsService.saml_settings(options)
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
        redirect_to url_service(user_session_form.saml_uuid).login_redirect_url
        if location.start_with?(url_service.base_redirect_url)
          # only record success stats if the user is being redirect to the site
          # some users will need to be up-leveled and this will be redirected
          # back to the identity provider
          login_stats(:success, saml_response, user_session_form)
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

    def login_stats_success(saml_response, user_session_form = nil)
      tracker = url_service(user_session_form&.saml_uuid).tracker
      tags = ["context:#{saml_response.authn_context}", VERSION_TAG]
      StatsD.increment(STATSD_LOGIN_NEW_USER_KEY, tags: [VERSION_TAG]) if request_type == 'signup'
      # track users who have a shared sso cookie
      StatsD.increment(STATSD_LOGIN_SHARED_COOKIE, tags: tags)
      StatsD.increment(STATSD_LOGIN_STATUS, tags: tags + ['status:success'])
      StatsD.measure(STATSD_LOGIN_LATENCY, tracker.age, tags: tags)
      callback_stats(:success, saml_response)
    end

    def new_stats(type)
      tags = ["context:#{type}", VERSION_TAG]
      StatsD.increment(STATSD_SSO_NEW_KEY, tags: tags)
      StatsD.increment(STATSD_SSO_NEW_FORCEAUTH, tags: tags) if force_authn?
      StatsD.increment(STATSD_SSO_NEW_INBOUND, tags: tags) if inbound_ssoe?
    end

    def login_stats(status, saml_response, user_session_form = nil)
      case status
      when :success
        login_stats_success(saml_response, user_session_form)
      when :failure
        StatsD.increment(STATSD_LOGIN_STATUS,
                         tags: ['status:failure',
                                "context:#{saml_response.authn_context}",
                                VERSION_TAG])
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
      set_sso_cookie!
    end

    def after_login_actions
      AfterLoginJob.perform_async('user_uuid' => @current_user&.uuid)
      log_persisted_session_and_warnings
    end

    def log_persisted_session_and_warnings
      obscure_token = Session.obscure_token(@session_object.token)
      Rails.logger.info("Logged in user with id #{@session_object.uuid}, token #{obscure_token}")
      # We want to log when SSNs do not match between MVI and SAML Identity. And might take future
      # action if this appears to be happening frequently.
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

    def url_service(previous_saml_uuid = nil)
      SAML::URLService.new(saml_settings,
                           session: @session_object,
                           user: current_user,
                           params: params,
                           loa3_context: LOA::IDME_LOA3,
                           previous_saml_uuid: previous_saml_uuid)
    end
  end
end
