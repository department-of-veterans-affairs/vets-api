# frozen_string_literal: true

require 'base64'

module V0
  class SessionsController < ApplicationController
    skip_before_action :authenticate, only: %i[new authn_urls saml_callback saml_logout_callback]

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

    # Collection Action: no auth required
    # Returns the sign-in urls for mhv, dslogon, and ID.me (LOA1 only)
    # authn_context is the policy, connect represents the ID.me flow
    # TODO: DEPRECATED
    def authn_urls
      render json: {
        mhv: SAML::SettingsService.mhv_url,
        dslogon: SAML::SettingsService.dslogon_url,
        idme: SAML::SettingsService.idme_loa1_url
      }
    end

    # Collection Action: auth is required for certain types of requests
    # @type is set automatically by the routes in config/routes.rb
    # For more details see SAML::SettingsService and SAML::URLService
    # TODO: when deprecated routes can be removed this should be changed to use different method (ie. destroy)
    # rubocop:disable Metrics/CyclomaticComplexity
    def new
      case params[:type]
      when 'mhv'
        redirect_to SAML::SettingsService.mhv_url
      when 'dslogon'
        redirect_to SAML::SettingsService.dslogon_url
      when 'idme'
        redirect_to SAML::SettingsService.idme_loa1_url
      when 'mfa'
        authenticate
        redirect_to SAML::SettingsService.mfa_url(current_user)
      when 'verify'
        authenticate
        redirect_to SAML::SettingsService.idme_loa3_url(current_user)
      when 'slo'
        authenticate
        redirect_to SAML::SettingsService.slo_url(session)
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    # Member Action: auth token required
    # method is to opt in to MFA for those users who opted out
    # authn_context is the policy, connect represents the ID.me flow
    # TODO: DEPRECATED
    def multifactor
      render json: { multifactor_url: SAML::SettingsService.mfa_url(current_user) }
    end

    # Member Action: auth token required
    # method is to verify LOA3. It is not necessary to verify for DSLogon or MHV who are PREMIUM users.
    # These sign-in users return LOA3 from the auth_url flow.
    # TODO: DEPRECATED
    def identity_proof
      render json: {
        identity_proof_url: SAML::SettingsService.idme_loa3_url(current_user)
      }
    end

    # TODO: DEPRECATED
    def destroy
      render json: { logout_via_get: SAML::SettingsService.slo_url(session) }, status: 202
    end

    def saml_logout_callback
      saml_settings = saml_settings(name_identifier_value: session&.uuid)
      logout_response = OneLogin::RubySaml::Logoutresponse.new(params[:SAMLResponse], saml_settings, get_params: params)
      logout_request  = SingleLogoutRequest.find(logout_response&.in_response_to)
      session         = Session.find(logout_request&.token)
      user            = User.find(session&.uuid)

      errors = build_logout_errors(logout_response, logout_request, session, user)

      if errors.size.positive?
        extra_context = { in_response_to: logout_response&.in_response_to }
        log_message_to_sentry("SAML Logout failed!\n  " + errors.join("\n  "), :error, extra_context)
      end
      # in the future the FE shouldnt count on ?success=true
    ensure
      destroy_user_session!(user, session, logout_request)
      redirect_to Settings.saml.logout_relay + '?success=true'
    end

    # rubocop:disable Metrics/MethodLength
    def saml_callback
      saml_response = OneLogin::RubySaml::Response.new(params[:SAMLResponse], settings: saml_settings)
      @sso_service = SSOService.new(saml_response)

      if @sso_service.persist_authentication!
        @current_user = @sso_service.new_user
        @session = @sso_service.new_session
        async_create_evss_account(current_user)
        redirect_to saml_callback_success_url

        log_persisted_session_and_warnings
        StatsD.increment(STATSD_LOGIN_NEW_USER_KEY) if @sso_service.new_login?
        StatsD.increment(STATSD_SSO_CALLBACK_KEY, tags: ['status:success', "context:#{context_key}"])
      else
        redirect_to Settings.saml.relay + '?auth=fail'
        StatsD.increment(STATSD_SSO_CALLBACK_KEY, tags: ['status:failure', "context:#{context_key}"])
        StatsD.increment(STATSD_SSO_CALLBACK_FAILED_KEY, tags: [@sso_service.failure_instrumentation_tag])
      end
    rescue NoMethodError
      Raven.extra_context(
        base64_params_saml_response: Base64.encode64(params[:SAMLResponse])
      )
      raise
    ensure
      StatsD.increment(STATSD_SSO_CALLBACK_TOTAL_KEY)
    end
    # rubocop:enable Metrics/MethodLength

    private

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

    def async_create_evss_account(user)
      return unless user.authorize :evss, :access?
      auth_headers = EVSS::AuthHeaders.new(user).to_h
      EVSS::CreateUserAccountJob.perform_async(auth_headers)
    end

    # FIXME: This is Phase 1 of 2 more details here:
    # https://github.com/department-of-veterans-affairs/vets-api/pull/1750
    # Eventually this call will happen when #destroy or 'sessions/slow/new' are first invoked.
    def destroy_user_session!(user, session, logout_request)
      # shouldn't return an error, but we'll put everything else in an ensure block just in case.
      MHVLoggingService.logout(user) if user
    ensure
      logout_request&.destroy
      session&.destroy
      user&.destroy
    end

    def build_logout_errors(logout_response, logout_request, session, user)
      errors = []
      errors.concat(logout_response.errors) unless logout_response.validate(true)
      errors << 'inResponseTo attribute is nil!' if logout_response&.in_response_to.nil?
      errors << 'Logout Request not found!' if logout_request.nil?
      errors << 'Session not found!' if session.nil?
      errors << 'User not found!' if user.nil?
      errors
    end

    def saml_callback_success_url
      if current_user.loa[:current] < current_user.loa[:highest]
        SAML::SettingsService.idme_loa3_url(current_user)
      else
        Settings.saml.relay + '?token=' + @session.token
      end
    rescue NoMethodError
      Raven.user_context(user_context)
      Raven.tags_context(tags_context)
      log_message_to_sentry('SSO Callback Success URL', :warn)
      Settings.saml.relay + '?token=' + @session.token
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
  end
end
