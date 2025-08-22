module SignIn
  module Webauthn
    module Registration
      class Verifier
        def initialize(current_user_verification, registration, challenge_id)
          @current_user_verification = current_user_verification
          @registration = registration
          @challenge_id = challenge_id
        end

        def perform
          verify_credential_challenge!

          ActiveRecord::Base.transaction do
            create_webauthn_credential!
            create_user_verification!
            create_user_credential_email!
          rescue => e
            Rails.logger.error("WebAuthn registration failed: #{e.message}")

            raise ActiveRecord::Rollback
          end

          true
        rescue => e
          Rails.logger.error("WebAuthn verification failed: #{e.message}")
          false
        end

        private

        attr_reader :current_user_verification, :registration, :webauthn_credential, :user_verification, :challenge_id

        def create_webauthn_credential!
          @webauthn_credential = SignIn::WebauthnCredential.create!(
            credential_id: credential.id,
            public_key: credential.public_key,
            sign_count: credential.sign_count,
            transports: credential.response.transports,
            aaguid: credential.response.attestation_object.aaguid,
            backed_up: credential.backed_up?,
            backup_eligible: credential.backup_eligible?
          )
        end

        def create_user_verification!
          @user_verification = UserVerification.create!(
            user_account: current_user_verification.user_account,
            webauthn_credential_id: webauthn_credential.id
          )
        end

        def create_user_credential_email!
          UserCredentialEmail.create!(
            user_verification:,
            credential_email: current_user_verification.user_credential_email.credential_email
          )
        end

        def credential
          @credential ||= WebAuthn::Credential.from_create(registration)
        end

        def verify_credential_challenge!
          credential.verify(challenge, user_verification: 'required')
        end

        def challenge
          @challenge ||= begin
            cache_key = "#{Registration::OptionsGenerator::CACHE_KEY_PREFIX}:#{challenge_id}"

            challenge = Rails.cache.read(cache_key)
            Rails.cache.delete(cache_key)

            raise 'Invalid or expired challenge' if challenge.nil?

            challenge
          end
        end
      end
    end
  end
end
