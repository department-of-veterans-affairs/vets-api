# frozen_string_literal: true
module V0
  class SessionsController < ApplicationController
    skip_before_action :authenticate, only: [:new, :saml_callback, :saml_logout]

    def new
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      render json: { authenticate_via_get: saml_auth_request.create(saml_settings) }
    end

    def show
      render json: @session
    end

    def destroy
      logout_request = OneLogin::RubySaml::Logoutrequest.new
      session[:slo_transaction_id] = logout_request.uuid
      logger.info "New SP SLO for userid '#{@session.uuid}' transactionid '#{session[:slo_transaction_id]}'"

      if saml_settings.name_identifier_value.nil?
        saml_settings.name_identifier_value = @session.uuid
      end

      render json: { logout_via_get: logout_request.create(saml_settings, RelayState: saml_logout_url) }, status: 202
    end

    def saml_logout
      # # If the IDP has initiated the logout, generate a response to it
      if params[:SAMLRequest]
        handle_idp_initiated_logout
      # We initiated an SLO and are receiving the bounce-back after the IDP performed it
      elsif params[:SAMLResponse]
        handle_completed_slo
      end
    end

    def saml_callback
      @saml_response = OneLogin::RubySaml::Response.new(
        params[:SAMLResponse], settings: saml_settings
      )

      if @saml_response.is_valid?
        persist_session_and_user!
        redirect_to SAML_CONFIG['relay'] + '?token=' + @session.token
      else
        redirect_to SAML_CONFIG['relay'] + '?auth=fail'
      end
    end

    private

    def persist_session_and_user!
      @session = Session.new(user_attributes.slice(:uuid))
      @current_user = User.find(@session.uuid)
      @current_user = saml_user if @current_user.nil? || up_level?
      @session.save && @current_user.save
      async_create_evss_account(@current_user)
    end

    def up_level?
      @current_user.loa[:current] <= saml_user.loa[:current]
    end

    def user_attributes
      attributes = @saml_response.attributes.all.to_h
      {
        first_name:     attributes['fname']&.first,
        middle_name:    attributes['mname']&.first,
        last_name:      attributes['lname']&.first,
        zip:            attributes['zip']&.first,
        email:          attributes['email']&.first,
        gender:         parse_gender(attributes['gender']&.first),
        ssn:            attributes['social']&.first&.delete('-'),
        birth_date:     parse_date(attributes['birth_date']&.first),
        uuid:           attributes['uuid']&.first,
        last_signed_in: Time.current.utc,
        loa:            { current: parse_current_loa, highest: attributes['level_of_assurance']&.first&.to_i }
      }
    end

    def parse_date(date_string)
      Time.parse(date_string).utc unless date_string.nil?
    rescue TypeError => e
      Rails.logger.error "error: #{e.message} when parsing date from saml date string: #{date_string.inspect}"
      nil
    end

    def parse_gender(gender)
      return nil unless gender
      gender[0].upcase
    end

    def parse_current_loa
      raw_loa = REXML::XPath.first(@saml_response.decrypted_document, '//saml:AuthnContextClassRef')&.text
      LOA::MAPPING[raw_loa]
    end

    def saml_user
      @saml_user ||= create_saml_user
    end

    def create_saml_user
      user = User.new(user_attributes)
      user = Decorators::MviUserDecorator.new(user).create unless user.loa1?
      user
    end

    def async_create_evss_account(user)
      return unless user.can_access_evss?
      auth_headers = EVSS::AuthHeaders.new(user).to_h
      EVSS::CreateUserAccountJob.perform_async(auth_headers)
    end

    def handle_completed_slo
      if session.key? :slo_transaction_id
        logout_response = OneLogin::RubySaml::Logoutresponse.new(
          params[:SAMLResponse],
          saml_settings,
          matches_request_id: session[:slo_transaction_id]
        )
      else
        logout_response = OneLogin::RubySaml::Logoutresponse.new(params[:SAMLResponse], saml_settings)
      end

      logger.info "LogoutResponse is: #{logout_response}"

      #
      # The response is going to be invalid. When I jump in with the debugger it says the document
      # enclosed in the SAML response is:
      #
      # <samlp:Response Destination='http://localhost:3000/auth/saml/logout' ID='_c7218fac146d44cd9027d4ec7398847b' InResponseTo='_ebce7393-a0bc-434c-ab2f-da8683d05fe7' IssueInstant='2016-11-03T18:43:51Z' Version='2.0' xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion' xmlns:samlp='urn:oasis:names:tc:SAML:2.0:protocol'>
      #   <saml:Issuer>api.idmelabs.com</saml:Issuer>
      #   <samlp:Status>
      #     <samlp:StatusCode Value='urn:oasis:names:tc:SAML:2.0:status:Requester'/>
      #     <samlp:StatusMessage>Received logout without an EncryptedID.</samlp:StatusMessage>
      #   </samlp:Status>
      # </samlp:Response>
      if !logout_response.validate
        logger.error 'The SAML Logout Response is invalid'
      elsif logout_response.success?
        logger.info "Delete session for '#{@session.uuid}'"
        delete_session
      end
    end

    def handle_idp_initiated_logout
      logout_request = OneLogin::RubySaml::SloLogoutrequest.new(params[:SAMLRequest])

      unless logout_request.is_valid?
        logger.error 'IdP initiated LogoutRequest was not valid!'
        render inline: logger.error
        return
      end

      logger.info "IdP initiated logout for #{logout_request.name_id}"

      # Actually log out this session
      delete_session

      # Generate a response to the IdP.
      logout_request_id = logout_request.id
      logout_response = OneLogin::RubySaml::SloLogoutresponse.new.create(
        saml_settings,
        logout_request_id,
        nil,
        RelayState: params[:RelayState]
      )

      redirect_to logout_response
    end

    def delete_session
      @session.destroy
    end
  end
end
