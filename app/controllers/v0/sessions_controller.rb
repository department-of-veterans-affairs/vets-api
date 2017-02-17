# frozen_string_literal: true
require 'saml/auth_fail_handler'

module V0
  class SessionsController < ApplicationController
    skip_before_action :authenticate, only: [:new, :saml_callback, :saml_logout_callback]

    def new
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      render json: { authenticate_via_get: saml_auth_request.create(saml_settings, saml_options) }
    end

    def destroy
      logout_request = OneLogin::RubySaml::Logoutrequest.new
      logger.info "New SP SLO for userid '#{@session.uuid}'"

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
        redirect_to SAML_CONFIG['relay'] + '?token=' + @session.token

        obscure_token = Session.obscure_token(@session.token)
        Rails.logger.info("Logged in user with id #{@session.uuid}, token #{obscure_token}")
      else
        handle_login_error
        redirect_to SAML_CONFIG['relay'] + '?auth=fail'
      end
    end

    private

    def persist_session_and_user
      saml_user = User.from_saml(@saml_response)

      @session = Session.new(uuid: saml_user.uuid)
      @current_user = User.find(@session.uuid)

      @current_user = @current_user.nil? ? saml_user : User.from_merged_attrs(@current_user, saml_user)
      @session.save && @current_user.save
    end

    def handle_login_error
      fail_handler = SAML::AuthFailHandler.new(@saml_response, @current_user, @session)
      if fail_handler.known_error?
        log_to_sentry(fail_handler.message, fail_handler.level, fail_handler.context)
      else
        log_to_sentry(fail_handler.generic_error_message, :error)
      end
    end

    def async_create_evss_account(user)
      return unless user.can_access_evss?
      auth_headers = EVSS::AuthHeaders.new(user).to_h
      EVSS::CreateUserAccountJob.perform_async(auth_headers)
    end

    def handle_completed_slo
      logout_response = OneLogin::RubySaml::Logoutresponse.new(params[:SAMLResponse], saml_settings, get_params: params)
      logout_request  = SingleLogoutRequest.find(logout_response&.in_response_to)
      session         = Session.find(logout_request&.token)
      user            = User.find(session&.uuid)

      errors = build_logout_errors(logout_response, logout_request, session, user)

      if errors.size.positive?
        extra_context = { in_response_to: logout_response&.in_response_to }
        log_to_sentry("SAML Logout failed!\n  " + errors.join("\n  "), :error, extra_context)
        redirect_to SAML_CONFIG['logout_relay'] + '?success=false'
      else
        logout_request.destroy
        session.destroy
        user.destroy
        redirect_to SAML_CONFIG['logout_relay'] + '?success=true'
        # even if mhv logout raises exception, still consider logout successful from browser POV
        MHVLoggingService.logout(user)
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

    def log_to_sentry(message, level, context = {})
      logger.send(level.to_sym, message + ' : ' + context.to_s)
      if ENV['SENTRY_DSN'].present?
        Raven.extra_context(context) unless !context.is_a?(Hash) || context.empty?
        Raven.capture_message(message, level: level)
      end
    end

    def saml_options
      ENV['REVIEW_INSTANCE_SLUG'].blank? ? {} : { RelayState: ENV['REVIEW_INSTANCE_SLUG'] }
    end
  end
end
