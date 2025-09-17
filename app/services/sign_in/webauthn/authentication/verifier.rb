# frozen_string_literal: true

module SignIn
  module Webauthn
    module Authentication
      class Verifier
        def initialize(authentication, challenge_id)
          @authentication = authentication
          @challenge_id   = challenge_id
        end

        def perform
          verify_credential_challenge!
          verify_assertion!
          update_sign_count_if_needed!

          create_session!
        rescue => e
          Rails.logger.error("WebAuthn authentication verification failed: #{e.message}")
          raise
        end

        private

        attr_reader :authentication, :challenge_id, :challenge

        def webauthn_credential
          @webauthn_credential ||= ::SignIn::WebauthnCredential
                                   .includes(:user_verification)
                                   .find_by!(credential_id: credential.id)
        end

        def verify_assertion!
          credential.verify(
            challenge,
            public_key: webauthn_credential.public_key,
            sign_count: webauthn_credential.sign_count,
            user_verification: 'required'
          )
        end

        def update_sign_count_if_needed!
          new_count = credential.sign_count
          return unless new_count && new_count > webauthn_credential.sign_count

          webauthn_credential.update!(sign_count: new_count)
        end

        def create_session!
          SessionCreator.new(validated_credential:).perform
        end

        def validated_credential
          ValidatedCredential.new(user_verification:,
                                  credential_email:,
                                  client_config:,
                                  user_attributes: nil,
                                  device_sso: nil,
                                  web_sso_session_id: nil)
        end

        def client_config
          @client_config ||= SignIn::ClientConfig.find_by(client_id: 'vaweb')
        end

        def user_verification
          @user_verification ||= webauthn_credential.user_verification
        end

        def credential_email
          @credential_email ||= user_verification.user_credential_email.credential_email
        end

        def user_account
          @user_account ||= user_verification&.user_account
        end

        def credential
          @credential ||= WebAuthn::Credential.from_get(authentication)
        end

        def verify_credential_challenge!
          cache_key = "#{Authentication::OptionsGenerator::CACHE_KEY_PREFIX}:#{challenge_id}"

          cached = Rails.cache.read(cache_key)
          Rails.cache.delete(cache_key)

          raise 'Invalid or expired challenge' if cached.nil?

          @challenge = cached
        end
      end
    end
  end
end
