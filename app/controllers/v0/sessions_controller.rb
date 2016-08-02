module V0
  class SessionsController < ApplicationController
    before_action :require_login, only: [:show]

    def new
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      redirect_to saml_auth_request.create(SAML::SETTINGS)
    end

    def show
      render json: profile_from_session_attributes
    end

    def destroy
      session[:user] = nil
      redirect_to root_path
    end

    def saml_callback
      saml_response = OneLogin::RubySaml::Response.new(
        params[:SAMLResponse], settings: SAML::SETTINGS)

      if saml_response.is_valid?
        session[:user] = {
          name: saml_response.name_id,
          attributes: saml_response.attributes.all.to_h
        }

        redirect_after_login
      else
        render json: saml_response.errors, status: :forbidden
      end
    end

    private

    def redirect_after_login
      if flash[:after_login_controller] && flash[:after_login_action]
        redirect_to controller: flash[:after_login_controller], action: flash[:after_login_action]
      else
        redirect_to v0_profile_path
      end
    end

    def profile_from_session_attributes
      attributes = session[:user]["attributes"]
      {
        first_name: attributes["fname"],
        last_name: attributes["lname"],
        zip: attributes["zip"],
        email: attributes["email"],
        uuid: attributes["uuid"]
      }
    end
  end
end
