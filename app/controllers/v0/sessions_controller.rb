module V0
  class SessionsController < ApplicationController
    before_action :authenticate, only: [:show, :destroy]

    def new
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      # TODO anyway to do this without redirect?
      redirect_to saml_auth_request.create(SAML::SETTINGS)
    end

    def show
      render json: @current_user
    end

    def destroy
      # @session.destroy currently not implemented
    end

    def saml_callback
      @saml_response = OneLogin::RubySaml::Response.new(
        params[:SAMLResponse], settings: SAML::SETTINGS)

      if @saml_response.is_valid?
        if persist_session_and_user!
          # TODO: this should probably return HTTP Authentication header
          render json: session, status: :created
        else
          # TODO: this is just for now, should raise exception and catch it
          # but this will help with debugging for now.
          render json: session.errors.full_messages, status: :forbidden
        end
      else
        # TODO: similarly here, also need to make sure error json conforms to api spec
        render json: saml_response.errors, status: :forbidden
      end
    end

    private

    def persist_session_and_user!
      session = Session.new(user_attributes.slice(:uuid))
      user = User.find(session.uuid) || User.new(user_attributes)
      session.save && user.save
    end

    def user_attributes
      attributes = @saml_response.attributes.all.to_h
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
