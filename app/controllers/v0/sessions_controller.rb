# frozen_string_literal: true

require 'base64'

module V0
  class SessionsController < ApplicationController
    skip_before_action :authenticate, only: %i[new logout saml_callback saml_logout_callback]

    REDIRECT_URLS = %w[mhv dslogon idme mfa verify slo].freeze

    STATSD_SSO_CALLBACK_KEY = 'api.auth.saml_callback'
    STATSD_SSO_CALLBACK_TOTAL_KEY = 'api.auth.login_callback.total'
    STATSD_SSO_CALLBACK_FAILED_KEY = 'api.auth.login_callback.failed'
    STATSD_LOGIN_NEW_USER_KEY = 'api.auth.new_user'
    STATSD_CONTEXT_MAP = {
      LOA::MAPPING.invert[1] => 'idme',
      'dslogon' => 'dslogon',
      'myhealthevet' => 'myhealthevet',
      LOA::MAPPING.invert[3] => 'idproof',
      'multifactor' => 'multifactor',
      'dslogon_multifactor' => 'dslogon_multifactor',
      'myhealthevet_multifactor' => 'myhealthevet_multifactor'
    }.freeze

    # Collection Action: auth is required for certain types of requests
    # @type is set automatically by the routes in config/routes.rb
    # For more details see SAML::SettingsService and SAML::URLService
    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
    def new
      url = case params[:type]
            when 'mhv'
              SAML::SettingsService.mhv_url(relay_state)
            when 'dslogon'
              SAML::SettingsService.dslogon_url(relay_state)
            when 'idme'
              query = params[:signup] ? '&op=signup' : ''
              SAML::SettingsService.idme_loa1_url(relay_state) + query
            when 'mfa'
              authenticate
              SAML::SettingsService.mfa_url(current_user, relay_state)
            when 'verify'
              authenticate
              SAML::SettingsService.idme_loa3_url(current_user, relay_state)
            when 'slo'
              authenticate
              # HACK: should figure out why relay_state logic is not working.
              logout_url = SAML::SettingsService.logout_url(session, relay_state)
              if request.cookies[Settings.sso.cookie_name].present?
                logout_url.gsub('vets.gov', 'va.gov')
              else
                logout_url
              end
            end
      render json: { url: url }
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength

    def logout
      session = Session.find(Base64.urlsafe_decode64(params[:session]))
      raise Common::Exceptions::Forbidden, detail: 'Invalid request' if session.nil?
      destroy_user_session!(User.find(session.uuid), session)
      redirect_to SAML::SettingsService.slo_url(session, relay_state)
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
      # in the future the FE shouldnt count on ?success=true
    ensure
      logout_request&.destroy
      redirect_to relay_state.logout_url + '?success=true'
    end

    def saml_callback
      saml_response = OneLogin::RubySaml::Response.new(params[:SAMLResponse], settings: saml_settings)
      @sso_service = SSOService.new(saml_response)
      if @sso_service.persist_authentication!
        @current_user = @sso_service.new_user
        @session = @sso_service.new_session

        after_login_actions
        redirect_to saml_login_relay_url + '?token=' + @session.token

        log_persisted_session_and_warnings
        StatsD.increment(STATSD_LOGIN_NEW_USER_KEY) if @sso_service.new_login?
        StatsD.increment(STATSD_SSO_CALLBACK_KEY, tags: ['status:success', "context:#{context_key}"])
      else
        redirect_to saml_login_relay_url + "?auth=fail&code=#{@sso_service.auth_error_code}"
        StatsD.increment(STATSD_SSO_CALLBACK_KEY, tags: ['status:failure', "context:#{context_key}"])
        StatsD.increment(STATSD_SSO_CALLBACK_FAILED_KEY, tags: [@sso_service.failure_instrumentation_tag])
      end
    ensure
      StatsD.increment(STATSD_SSO_CALLBACK_TOTAL_KEY)
    end

    private

    def saml_login_relay_url
      return relay_state.default_login_url if current_user.nil?
      # TODO: this validation should happen when we create the user, not here
      if current_user.loa.key?(:highest) == false || current_user.loa[:highest].nil?
        log_message_to_sentry('ID.me did not provide LOA.highest!', :error)
        return relay_state.default_login_url
      end

      if current_user.loa[:current] < current_user.loa[:highest]
        SAML::SettingsService.idme_loa3_url(current_user, relay_state)
      else
        relay_state.login_url
      end
    end

    def after_login_actions
      set_sso_cookie!
      AfterLoginJob.perform_async('user_uuid' => @current_user&.uuid)
    end

    def log_persisted_session_and_warnings
      obscure_token = Session.obscure_token(session.token)
      Rails.logger.info("Logged in user with id #{session.uuid}, token #{obscure_token}")
      # We want to log when SSNs do not match between MVI and SAML Identity. And might take future
      # action if this appears to be happening frquently.
      if current_user.ssn_mismatch?
        additional_context = StringHelpers.heuristics(current_user.identity.ssn, current_user.va_profile.ssn)
        log_message_to_sentry('SSNS DO NOT MATCH!!', :warn, identity_compared_with_mvi: additional_context)
      end
    end

    def destroy_user_session!(user, session)
      # shouldn't return an error, but we'll put everything else in an ensure block just in case.
      MHVLoggingService.logout(user) if user
    ensure
      destroy_sso_cookie!
      session&.destroy
      user&.destroy
    end

    def build_logout_errors(logout_response, logout_request)
      errors = []
      errors.concat(logout_response.errors) unless logout_response.validate(true)
      errors << 'inResponseTo attribute is nil!' if logout_response&.in_response_to.nil?
      errors << 'Logout Request not found!' if logout_request.nil?
      errors
    end

    def benchmark_tags(*tags)
      tags << "context:#{context_key}"
      tags << "loa:#{current_user&.identity ? current_user.loa[:current] : 'none'}"
      tags << "multifactor:#{current_user&.identity ? current_user.multifactor : 'none'}"
      tags
    end

    def context_key
      STATSD_CONTEXT_MAP[@sso_service.real_authn_context] || 'unknown'
    rescue StandardError
      'unknown'
    end

    def relay_state
      @relay_state ||= RelayState.new(relay_enum: params[:success_relay], url: params[:RelayState])
    end
  end
end
