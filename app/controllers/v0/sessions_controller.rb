module V0
  class SessionsController < ApplicationController

    def new
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      redirect_to saml_auth_request.create(SAML::SETTINGS)
    end

    def show
      if session[:user]
        attributes = session[:user]["attributes"]
        profile = {
            first_name: attributes['fname'],
            last_name: attributes['lname'],
            zip: attributes['zip'],
            email: attributes['email'],
            uid: attributes['uuid']
          }

        render json: profile
      else
        redirect_to action: "create"
      end
    end

    def destroy
      session[:user] = nil
      redirect_to root_url
    end

    def saml_callback
      saml_response = OneLogin::RubySaml::Response.new(
          params[:SAMLResponse], settings: SAML::SETTINGS)

      if saml_response.is_valid?
        session[:user] = {
            name: saml_response.name_id,
            attributes: saml_response.attributes.all.to_h
          }
        redirect_to v0_welcome_path
      else
        render json: saml_response.errors, status: :forbidden
      end
    end
  end
end