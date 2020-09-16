# frozen_string_literal: true

require 'base64'
require 'saml/errors'
require 'saml/post_url_service'
require 'saml/responses/login'
require 'saml/responses/logout'
require 'saml/ssoe_settings_service'
require 'saml/url_service'

module V1
  class SessionsController < ApplicationController
    skip_before_action :verify_authenticity_token

    REDIRECT_URLS = %w[signup mhv dslogon idme custom mfa verify slo].freeze
    STATSD_SSO_NEW_KEY = 'api.auth.new'
    STATSD_SSO_SAMLREQUEST_KEY = 'api.auth.saml_request'
    STATSD_SSO_SAMLRESPONSE_KEY = 'api.auth.saml_response'
    STATSD_SSO_SAMLTRACKER_KEY = 'api.auth.saml_tracker'
    STATSD_SSO_CALLBACK_KEY = 'api.auth.saml_callback'
    STATSD_SSO_CALLBACK_TOTAL_KEY = 'api.auth.login_callback.total'
    STATSD_SSO_CALLBACK_FAILED_KEY = 'api.auth.login_callback.failed'
    STATSD_LOGIN_NEW_USER_KEY = 'api.auth.new_user'
    STATSD_LOGIN_STATUS_SUCCESS = 'api.auth.login.success'
    STATSD_LOGIN_STATUS_FAILURE = 'api.auth.login.failure'
    STATSD_LOGIN_LATENCY = 'api.auth.latency'
    VERSION_TAG = 'version:v1'

    # Collection Action: auth is required for certain types of requests
    # @type is set automatically by the routes in config/routes.rb
    # For more details see SAML::SettingsService and SAML::URLService
    def new
      type = params[:type]

      if type == 'slo'
        Rails.logger.info("LOGOUT of type #{type}", sso_logging_info)
        reset_session
        url = url_service.ssoe_slo_url
        # due to shared url service implementation
        # clientId must be added at the end or the URL will be invalid for users using various "Do not track"
        # extensions with their browser.
        redirect_to params[:client_id].present? ? url + "&clientId=#{params[:client_id]}" : url
      else
        render_login(type)
      end
      new_stats(type)
    end

    def ssoe_slo_callback
      redirect_to url_service.logout_redirect_url
    end

    def saml_callback
      set_sentry_context_for_callback if JSON.parse(params[:RelayState] || '{}')['type'] == 'mfa'
      saml_response = SAML::Responses::Login.new(params[:SAMLResponse], settings: saml_settings)
      saml_response_stats(saml_response)
      raise_saml_error(saml_response) unless saml_response.valid?
      user_login(saml_response)
      callback_stats(:success, saml_response)
    rescue SAML::SAMLError => e
      handle_callback_error(e, :failure, saml_response, e.level, e.context, e.code, e.tag)
    rescue => e
      # the saml_response variable may or may not be defined depending on
      # where the exception was raised
      resp = defined?(saml_response) && saml_response
      handle_callback_error(e, :failed_unknown, resp)
    ensure
      callback_stats(:total)
    end

    def tracker
      id = params[:id]
      type = params[:type]
      authn = params[:authn]
      values = { 'id' => id, 'type' => type, 'authn' => authn }
      if REDIRECT_URLS.include?(type) && SAML::User::AUTHN_CONTEXTS.keys.include?(authn)
        Rails.logger.info("SSOe: SAML Tracker => #{values}")
        StatsD.increment(STATSD_SSO_SAMLTRACKER_KEY,
                         tags: ["type:#{type}", "context:#{authn}", VERSION_TAG])
      end
    end

    def metadata
      meta = OneLogin::RubySaml::Metadata.new
      render xml: meta.generate(saml_settings), content_type: 'application/xml'
    end

    private

    def set_sentry_context_for_callback
      temp_session_object = Session.find(session[:token])
      temp_current_user = User.find(temp_session_object.uuid) if temp_session_object
      Raven.extra_context(
        current_user_uuid: temp_current_user.try(:uuid),
        current_user_icn: temp_current_user.try(:mhv_icn)
      )
    end

    def saml_settings(options = {})
      # add a forceAuthn value to the saml settings based on the initial options or
      # default to false
      options[:force_authn] ||= false
      SAML::SSOeSettingsService.saml_settings(options)
    end

    def raise_saml_error(form)
      code = form.error_code
      code = UserSessionForm::ERRORS[:saml_replay_valid_session][:code] if code == '005' && validate_session
      raise SAML::FormError.new(form, code)
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

    def user_login(saml_response)
      user_session_form = UserSessionForm.new(saml_response)
      raise_saml_error(user_session_form) unless user_session_form.valid?

      @current_user, @session_object = user_session_form.persist
      set_cookies
      after_login_actions
      helper = url_service(user_session_form.saml_uuid)
      if helper.should_uplevel?
        render_login('verify', user_session_form.saml_uuid)
      else
        redirect_to helper.login_redirect_url
        login_stats(:success, saml_response)
      end
    end

    def render_login(type, previous_saml_uuid = nil)
      force = (type != 'custom')
      helper = url_service(previous_saml_uuid, force)
      login_url, post_params = login_params(type, helper)
      renderer = ActionController::Base.renderer
      renderer.controller.prepend_view_path(Rails.root.join('lib', 'saml', 'templates'))
      result = renderer.render template: 'sso_post_form',
                               locals: {
                                 url: login_url,
                                 params: post_params,
                                 id: helper.tracker.uuid,
                                 authn: helper.tracker.payload_attr(:authn_context),
                                 type: helper.tracker.payload_attr(:type)
                               },
                               format: :html
      render body: result, content_type: 'text/html'
      saml_request_stats(helper.tracker)
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def login_params(type, helper)
      raise Common::Exceptions::RoutingError, type unless REDIRECT_URLS.include?(type)

      case type
      when 'signup'
        helper.signup_url
      when 'mhv'
        helper.mhv_url
      when 'dslogon'
        helper.dslogon_url
      when 'idme'
        helper.idme_url
      when 'mfa'
        helper.mfa_url
      when 'verify'
        helper.verify_url
      when 'custom'
        raise Common::Exceptions::ParameterMissing, 'authn' if params[:authn].blank?

        helper.custom_url params[:authn]
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def saml_request_stats(tracker)
      values = {
        'id' => tracker&.uuid,
        'authn' => tracker&.payload_attr(:authn_context),
        'type' => tracker&.payload_attr(:type)
      }
      Rails.logger.info("SSOe: SAML Request => #{values}")
      StatsD.increment(STATSD_SSO_SAMLREQUEST_KEY,
                       tags: ["type:#{tracker&.payload_attr(:type)}",
                              "context:#{tracker&.payload_attr(:authn_context)}",
                              VERSION_TAG])
    end

    def saml_response_stats(saml_response)
      type = JSON.parse(params[:RelayState] || '{}')['type']
      values = {
        'id' => saml_response.in_response_to,
        'authn' => saml_response.authn_context,
        'type' => type
      }
      Rails.logger.info("SSOe: SAML Response => #{values}")
      StatsD.increment(STATSD_SSO_SAMLRESPONSE_KEY,
                       tags: ["type:#{type}",
                              "context:#{saml_response.authn_context}",
                              VERSION_TAG])
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

    def new_stats(type)
      tags = ["context:#{type}", VERSION_TAG]
      StatsD.increment(STATSD_SSO_NEW_KEY, tags: tags)
      Rails.logger.info("SSO_NEW_KEY, tags: #{tags}")
    end

    def login_stats(status, saml_response, error = nil)
      tracker = url_service(saml_response&.in_response_to).tracker
      type = tracker.payload_attr(:type)
      tags = ["context:#{type}", VERSION_TAG]
      case status
      when :success
        StatsD.increment(STATSD_LOGIN_NEW_USER_KEY, tags: [VERSION_TAG]) if type == 'signup'
        StatsD.increment(STATSD_LOGIN_STATUS_SUCCESS, tags: tags)
        Rails.logger.info("LOGIN_STATUS_SUCCESS, tags: #{tags}")
        StatsD.measure(STATSD_LOGIN_LATENCY, tracker.age, tags: tags)
      when :failure
        tags_and_error_code = tags << "error:#{error.code}"
        StatsD.increment(STATSD_LOGIN_STATUS_FAILURE, tags: tags_and_error_code)
        Rails.logger.info("LOGIN_STATUS_FAILURE, tags: #{tags_and_error_code}")
      end
    end

    def callback_stats(status, saml_response = nil, failure_tag = nil)
      case status
      when :success
        StatsD.increment(STATSD_SSO_CALLBACK_KEY,
                         tags: ['status:success',
                                "context:#{saml_response&.authn_context}",
                                VERSION_TAG])
      when :failure
        tag = failure_tag.to_s.starts_with?('error:') ? failure_tag : "error:#{failure_tag}"
        StatsD.increment(STATSD_SSO_CALLBACK_KEY,
                         tags: ['status:failure',
                                "context:#{saml_response&.authn_context}",
                                VERSION_TAG])
        StatsD.increment(STATSD_SSO_CALLBACK_FAILED_KEY, tags: [tag, VERSION_TAG])
      when :failed_unknown
        StatsD.increment(STATSD_SSO_CALLBACK_KEY,
                         tags: ['status:failure', 'context:unknown', VERSION_TAG])
        StatsD.increment(STATSD_SSO_CALLBACK_FAILED_KEY, tags: ['error:unknown', VERSION_TAG])
      when :total
        StatsD.increment(STATSD_SSO_CALLBACK_TOTAL_KEY, tags: [VERSION_TAG])
      end
    end

    # rubocop:disable Metrics/ParameterLists
    def handle_callback_error(exc, status, response, level = :error, context = {},
                              code = '007', tag = nil)
      log_message_to_sentry(exc.message, level, extra_context: context)
      redirect_to url_service(response&.in_response_to).login_redirect_url(auth: 'fail', code: code) unless performed?
      login_stats(:failure, response, exc) unless response.nil?
      callback_stats(status, response, tag)
      PersonalInformationLog.create(
        error_class: exc,
        data: {
          request_id: request.uuid,
          payload: response&.response || params[:SAMLResponse]
        }
      )
    end
    # rubocop:enable Metrics/ParameterLists

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

    def url_service(previous_saml_uuid = nil, force_authn = false)
      SAML::PostURLService.new(saml_settings(force_authn: force_authn),
                               session: @session_object,
                               user: current_user,
                               params: params,
                               loa3_context: LOA::IDME_LOA3,
                               previous_saml_uuid: previous_saml_uuid)
    end
  end
end
