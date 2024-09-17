# frozen_string_literal: true

module V0
  class WebauthnController < ApplicationController
    def generate_registration_options
      user.update!(webauthn_id: WebAuthn.generate_user_id) unless user.webauthn_id

      options = WebAuthn::Credential.options_for_create(
        user: { id: user.webauthn_id, name: user.email },
        exclude: user.credentials.map { |c| c.webauthn_id },
        authenticator_selection: { user_verification: 'preferred' }
      )

      session[:creation_challenge] = options.challenge

      respond_to do |format|
        format.json { render json: options }
      end
    end

    def verify_registration
      webauthn_credential = WebAuthn::Credential.from_create(params[:publicKeyCredential])

      begin
        webauthn_credential.verify(session[:creation_challenge])

        # Store `Credential ID, Public Key, and Sign count for further authentications`
        user.credentials.create!(
          webauthn_id: webauthn_credential.id,
          public_key: webauthn_credential.public_key,
          sign_count: webauthn_credential.sign_count
        )
      rescue WebAuthn::Error => e
        # handle error
      end
    end

    def generate_authentication_options
      options = WebAuthn::Credential.options_for_get(
        allow: user.credentials.map { |c| c.webauthn_id }
      )

      options.as_json
    end

    def verify_authentication
      webauthn_credential = WebAuthn::Credential.from_get(params[:publicKeyCredential])

      stored_credential = user.credentials.find_by(webauthn_id: webauthn_credential.id)

      begin
        webauthn_credential.verify(
          session[:authentication_challenge],
          public_key: stored_credential.public_key,
          sign_count: stored_credential.sign_count
        )

        # Update the stored credential sign count with the value from `webauthn_credential.sign_count`
        stored_credential.update!(sign_count: webauthn_credential.sign_count)

        # Continue with successful sign in or 2FA verification?
      rescue WebAuthn::SignCountVerificationError => e
        # Cryptographic verification of the authenticator data succeeded, but the signature counter was less then or equal
        # to the stored value. This can have several reasons and depending on your risk tolerance you can choose to fail or
        # pass authentication. For more information see https://www.w3.org/TR/webauthn/#sign-counter
      rescue WebAuthn::Error => e
        # Handle error
      end
    end
  end
end
