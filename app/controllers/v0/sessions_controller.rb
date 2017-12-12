# frozen_string_literal: true
require 'saml/auth_fail_handler'

module V0
  class SessionsController < ApplicationController
    skip_before_action :authenticate, only: [:new, :authn_urls, :saml_callback, :saml_logout_callback]

    STATSD_CALLBACK_KEY = 'api.auth.saml_callback'
    STATSD_LOGIN_FAILED_KEY = 'api.auth.login_callback.failed'
    STATSD_LOGIN_TOTAL_KEY = 'api.auth.login_callback.total'
    STATSD_LOGIN_NEW_USER_KEY = 'api.auth.new_user'
    TIMER_LOGIN_KEY = 'api.auth.login'
    TIMER_LOGOUT_KEY = 'api.auth.logout'

    STATSD_CONTEXT_MAP = {
      LOA::MAPPING.invert[1] => 'idme',
      'dslogon' => 'dslogon',
      'myhealthevet' => 'myhealthevet',
      LOA::MAPPING.invert[3] => 'idproof',
      'multifactor' => 'multifactor',
      'dslogon_multifactor' => 'dslogon_multifactor',
      'myhealthevet_multifactor' => 'myhealthevet_multifactor'
    }.freeze

    # Collection Action: method will eventually replace new
    # Returns the sign-in urls for mhv, dslogon, and ID.me (LOA1 only)
    # authn_context is the policy, connect represents the ID.me flow
    # no auth required
    def authn_urls
      render json: {
        mhv: build_url(authn_context: 'myhealthevet', connect: 'myhealthevet'),
        dslogon: build_url(authn_context: 'dslogon', connect: 'dslogon'),
        idme: build_url
      }
    end

    # Member Action: method is to opt in to MFA for those users who opted out
    # authn_context is the policy, connect represents the ID.me flow
    # auth token required
    def multifactor
      policy = @current_user&.authn_context
      authn_context = policy.present? ? "#{policy}_multifactor" : 'multifactor'
      render json: { multifactor_url: build_url(authn_context: authn_context, connect: policy) }
    end

    # Member Action: method is to verify LOA3 if existing ID.me LOA3, or
    #  go through the FICAM identity proofing flow if not an ID.me LOA3 or NON PREMIUM DSLogon or MHV.
    # NOTE: This is FICAM LOA3 we're talking about here. It is not necessary to verify DSLogon or MHV
    #  sign-in users who return LOA3 from the auth_url flow (only for leveling up NON PREMIUM).
    # authn_context is the policy, connect represents the ID.me flow
    # auth token required
    def identity_proof
      connect = @current_user&.authn_context
      render json: {
        identity_proof_url: build_url(authn_context: LOA::MAPPING.invert[3], connect: connect)
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
      @saml_response = OneLogin::RubySaml::Response.new(
        params[:SAMLResponse], settings: saml_settings
      )

      if @saml_response.is_valid? && persist_session_and_user
        async_create_evss_account(@current_user)
        redirect_to Settings.saml.relay + '?token=' + @session.token

        obscure_token = Session.obscure_token(@session.token)
        Rails.logger.info("Logged in user with id #{@session.uuid}, token #{obscure_token}")
        Benchmark::Timer.stop(TIMER_LOGIN_KEY, @saml_response.in_response_to, tags: benchmark_tags('status:success'))
        StatsD.increment(STATSD_CALLBACK_KEY, tags: ['status:success', "context:#{context_key}"])
      else
        handle_login_error
        redirect_to Settings.saml.relay + '?auth=fail'
        Benchmark::Timer.stop(TIMER_LOGIN_KEY, @saml_response.in_response_to, tags: benchmark_tags('status:failure'))
      end
    ensure
      StatsD.increment(STATSD_LOGIN_TOTAL_KEY)
    end

    private

    def persist_session_and_user
      saml_attributes = SAML::User.new(@saml_response)
      existing_user = User.find(saml_attributes.user_attributes.uuid)
      user_identity = UserIdentity.new(saml_attributes.to_hash)
      # FIXME-IDENTITY-PHASE2: this line will go away
      old_current_user = init_new_user(user_identity, existing_user, saml_attributes.changing_multifactor?, UserOld)
      @current_user = init_new_user(user_identity, existing_user, saml_attributes.changing_multifactor?)

      if existing_user.present?
        existing_user&.identity&.destroy
        existing_user.destroy
      else
        StatsD.increment(STATSD_LOGIN_NEW_USER_KEY)
      end

      @session = Session.new(uuid: @current_user.uuid)
      # FIXME-IDENTITY-PHASE2: the last part of this line will go away
      @session.save && user_identity.save && @current_user.save && old_current_user.save
    end

    # FIXME-IDENTITY-PHASE2: won't need to specify klass as there will only e 1
    def init_new_user(user_identity, existing_user = nil, multifactor_change = false, klass = User)
      # Eventually it will be this
      # new_user = User.new(uuid: user_identity.uuid)
      new_user = klass.new(user_identity.attributes)
      if multifactor_change
        new_user.last_signed_in = existing_user.last_signed_in
        new_user.mhv_last_signed_in = existing_user.mhv_last_signed_in
      else
        new_user.last_signed_in = Time.current.utc
      end
      new_user
    end

    def handle_login_error
      fail_handler = SAML::AuthFailHandler.new(@saml_response)
      StatsD.increment(STATSD_CALLBACK_KEY, tags: ['status:failure', "context:#{context_key}"])
      if fail_handler.errors?
        StatsD.increment(STATSD_LOGIN_FAILED_KEY, tags: ["error:#{fail_handler.error}"])
        log_message_to_sentry(fail_handler.message, fail_handler.level, fail_handler.context)
      else
        StatsD.increment(STATSD_LOGIN_FAILED_KEY, tags: ['error:validations_failed'])
        context = {
          uuid: @current_user.uuid,
          user:   {
            valid: @current_user&.valid?,
            errors: @current_user&.errors&.full_messages
          },
          session:   {
            valid: @session&.valid?,
            errors: @session&.errors&.full_messages
          }
        }
        log_message_to_sentry('Login Fail! on User/Session Validation', :error, context)
      end
    end

    def async_create_evss_account(user)
      return unless user.can_access_evss?
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

    def context_key
      context = REXML::XPath.first(@saml_response.decrypted_document, '//saml:AuthnContextClassRef')&.text
      STATSD_CONTEXT_MAP[context] || 'unknown'
    rescue
      'unknown'
    end

    def benchmark_tags(*tags)
      tags << "context:#{context_key}"
      tags << "loa:#{@current_user.loa[:current]}" if @current_user && @current_user.identity
      tags << "multifactor:#{@current_user.multifactor}" if @current_user && @current_user.identity
      tags
    end
  end
end
