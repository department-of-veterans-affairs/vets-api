module V0
  class SessionsController < ApplicationController
    skip_before_action :authenticate, only: [:new, :saml_callback]

    def new
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      render json: { authenticate_via_get: saml_auth_request.create(SAML::SETTINGS) }
    end

    def show
      render json: @session
    end

    def destroy
      @session.destroy
      head :no_content
    end

    def saml_callback
      @saml_response = OneLogin::RubySaml::Response.new(
        params[:SAMLResponse], settings: SAML::SETTINGS)

      if @saml_response.is_valid?
        persist_session_and_user!
        render :send, status: :created
      else
        # TODO: also need to make sure error json conforms to api spec
        render json: { errors: @saml_response.errors.full_messages }, status: :forbidden
      end
    end

    private

    def persist_session_and_user!
      @session = Session.new(user_attributes.slice(:uuid))
      @current_user = User.find(@session.uuid) || User.new(user_attributes)
      @session.save && @current_user.save
    end

    def user_attributes
      attributes = @saml_response.attributes.all.to_h
      {
        first_name: attributes["fname"]&.first,
        last_name: attributes["lname"]&.first,
        zip: attributes["zip"]&.first,
        email: attributes["email"]&.first,
        uuid: attributes["uuid"]&.first
      }
    end
  end
end
