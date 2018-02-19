# frozen_string_literal: true

module V0
  class SessionsController < ApplicationController
    skip_before_action :authenticate, only: %i[new authn_urls saml_callback saml_logout_callback]

    STATSD_LOGIN_TOTAL_KEY = 'api.auth.login_callback.total'
    STATSD_LOGIN_NEW_USER_KEY = 'api.auth.new_user'
    TIMER_LOGIN_KEY = 'api.auth.login'
    TIMER_LOGOUT_KEY = 'api.auth.logout'

    # Collection Action: no auth required
    # Returns the sign-in urls for mhv, dslogon, and ID.me (LOA1 only)
    # authn_context is the policy, connect represents the ID.me flow
    def authn_urls
      render json: {
        mhv: build_url(authn_context: 'myhealthevet', connect: 'myhealthevet'),
        dslogon: build_url(authn_context: 'dslogon', connect: 'dslogon'),
        idme: build_url
      }
    end

    # Member Action: auth token required
    # method is to opt in to MFA for those users who opted out
    # authn_context is the policy, connect represents the ID.me flow
    def multifactor
      policy = @current_user&.authn_context
      authn_context = policy.present? ? "#{policy}_multifactor" : 'multifactor'
      render json: { multifactor_url: build_url(authn_context: authn_context, connect: policy) }
    end

    # Member Action: auth token required
    # method is to verify LOA3. It is not necessary to verify for DSLogon or MHV who are PREMIUM users.
    # These sign-in users return LOA3 from the auth_url flow.
    def identity_proof
      #  authn_context is the policy, connect represents the ID.me specific flow.
      render json: {
        identity_proof_url: build_url(authn_context: LOA::MAPPING.invert[3], connect: @current_user&.authn_context)
      }
    end

    def destroy
      logout_request = OneLogin::RubySaml::Logoutrequest.new
      logger.info "New SP SLO for userid '#{@session.uuid}'"

      Benchmark::Timer.start(TIMER_LOGOUT_KEY, logout_request.uuid)

      saml_settings = saml_settings(name_identifier_value: @session&.uuid)
      # cache the request for @session.token lookup when we receive the response
      SingleLogoutRequest.create(uuid: logout_request.uuid, token: @session.token)

      render json: { logout_via_get: logout_request.create(saml_settings, saml_options) }, status: 202
    end

    def saml_logout_callback
      if params[:SAMLResponse]
        # We initiated an SLO and are receiving the bounce-back after the IDP performed it
        handle_completed_slo
      end
    end

    def saml_callback
      saml_response = OneLogin::RubySaml::Response.new(params[:SAMLResponse], settings: saml_settings)
      @sso_service = SSOService.new(saml_response)

      if @sso_service.persist_authentication!
        StatsD.increment(STATSD_LOGIN_NEW_USER_KEY) if @sso_service.existing_user.blank?
        @current_user = @sso_service.new_user
        @session = @sso_service.new_session
        async_create_evss_account(@current_user)

        redirect_to Settings.saml.relay + '?token=' + @session.token

        log_persisted_session_and_warnings
        Benchmark::Timer.stop(TIMER_LOGIN_KEY, saml_response.in_response_to, tags: benchmark_tags('status:success'))
        StatsD.increment(
          SSOService::STATSD_CALLBACK_KEY,
          tags: ['status:success', "context:#{@sso_service.context_key}"]
        )
      else
        redirect_to Settings.saml.relay + '?auth=fail'

        Benchmark::Timer.stop(TIMER_LOGIN_KEY, saml_response.in_response_to, tags: benchmark_tags('status:failure'))
      end
    ensure
      StatsD.increment(STATSD_LOGIN_TOTAL_KEY)
    end

    private

    def log_persisted_session_and_warnings
      obscure_token = Session.obscure_token(@session.token)
      Rails.logger.info("Logged in user with id #{@session.uuid}, token #{obscure_token}")
      # We want to log when SSNs do not match between MVI and SAML Identity. And might take future
      # action if this appears to be happening frquently.
      if @current_user.ssn_mismatch?
        additional_context = StringHelpers.heuristics(@current_user.identity.ssn, @current_user.va_profile.ssn)
        log_message_to_sentry('SSNS DO NOT MATCH!!', :warn, identity_compared_with_mvi: additional_context)
      end
    end

    def async_create_evss_account(user)
      return unless Auth.authorized? user, :evss, :access?
      auth_headers = EVSS::AuthHeaders.new(user).to_h
      EVSS::CreateUserAccountJob.perform_async(auth_headers)
    end

    def handle_completed_slo
      saml_settings = saml_settings(name_identifier_value: @session&.uuid)
      logout_response = OneLogin::RubySaml::Logoutresponse.new(params[:SAMLResponse], saml_settings, get_params: params)
      logout_request  = SingleLogoutRequest.find(logout_response&.in_response_to)
      session         = Session.find(logout_request&.token)
      user            = User.find(session&.uuid)

      errors = build_logout_errors(logout_response, logout_request, session, user)

      if errors.size.positive?
        extra_context = { in_response_to: logout_response&.in_response_to }
        log_message_to_sentry("SAML Logout failed!\n  " + errors.join("\n  "), :error, extra_context)
        redirect_to Settings.saml.logout_relay + '?success=false'
        Benchmark::Timer.stop(TIMER_LOGOUT_KEY, logout_response&.in_response_to, tags: ['status:fail'])
      else
        logout_request.destroy
        session.destroy
        user.destroy
        redirect_to Settings.saml.logout_relay + '?success=true'
        # even if mhv logout raises exception, still consider logout successful from browser POV
        MHVLoggingService.logout(user)
        Benchmark::Timer.stop(TIMER_LOGOUT_KEY, logout_response.in_response_to, tags: ['status:success'])
      end
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

    def saml_options
      Settings.review_instance_slug.blank? ? {} : { RelayState: Settings.review_instance_slug }
    end

    # Builds the urls to trigger varios sign-in, mfa, or verify flows in idme.
    # nil authn_context and nil connect will always default to idme level 1
    def build_url(authn_context: LOA::MAPPING.invert[1], connect: nil)
      saml_settings = saml_settings(authn_context: authn_context, name_identifier_value: @session&.uuid)
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      Benchmark::Timer.start(TIMER_LOGIN_KEY, saml_auth_request.uuid)
      connect_param = "&connect=#{connect}"
      link = saml_auth_request.create(saml_settings, saml_options)
      connect.present? ? link + connect_param : link
    end

    def benchmark_tags(*tags)
      tags << "context:#{@sso_service.context_key}"
      tags << "loa:#{@current_user&.identity ? @current_user.loa[:current] : 'none'}"
      tags << "multifactor:#{@current_user&.identity ? @current_user.multifactor : 'none'}"
      tags
    end
  end
end
