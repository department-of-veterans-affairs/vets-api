# frozen_string_literal: true
module V0
  class SessionsController < ApplicationController
    skip_before_action :authenticate, only: [:new, :saml_callback, :saml_logout_callback]

    def new
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      render json: { authenticate_via_get: saml_auth_request.create(saml_settings) }
    end

    def destroy
      logout_request = OneLogin::RubySaml::Logoutrequest.new
      logger.info "New SP SLO for userid '#{@session.uuid}'"

      render json: { logout_via_get: logout_request.create(saml_settings, RelayState: @session.token) }, status: 202
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
      else
        log_errors
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

    def async_create_evss_account(user)
      return unless user.can_access_evss?
      auth_headers = EVSS::AuthHeaders.new(user).to_h
      EVSS::CreateUserAccountJob.perform_async(auth_headers)
    end

    # :nocov:
    def handle_completed_slo
      logout_response = OneLogin::RubySaml::Logoutresponse.new(params[:SAMLResponse], saml_settings)

      logger.info "LogoutResponse is: #{logout_response}"

      if !logout_response.validate(true)
        logger.error 'The SAML Logout Response is invalid'
        logger.error "ERROR MESSAGES #{logout_response.errors.join(' ---- ')}"
        redirect_to SAML_CONFIG['logout_relay'] + '?success=false'
      elsif logout_response.success?
        begin
          session = Session.find(params[:RelayState])
          user = User.find(session.uuid)
          MHVLoggingService.logout(user)
        rescue => e
          logger.error "Error in MHV Logout: #{e.message}"
        end
        delete_session(params[:RelayState])
        redirect_to SAML_CONFIG['logout_relay'] + '?success=true'
      end
    end

    def delete_session(token)
      session = Session.find(token)
      unless session.nil?
        User.find(session.uuid)&.destroy
        session.destroy
      end
    end
    # :nocov:

    def log_errors
      saml_error    = "valid?=#{@saml_response.is_valid?} errors=#{@saml_response.errors}"
      user_error    = "valid?=#{@current_user&.valid?} errors=#{@current_user&.errors&.full_messages}"
      session_error = "valid?=#{@session&.valid?} errors=#{@session&.errors&.full_messages}"

      logger.error 'Login with ID.me failed!'
      logger.error saml_error
      logger.error user_error
      logger.error session_error

      if ENV['SENTRY_DSN'].present?
        Raven.extra_context(
          saml_response: saml_error,
          session: session_error,
          user: user_error
        )
        Raven.capture_exception('Login with ID.me failed!')
      end
    end
  end
end
