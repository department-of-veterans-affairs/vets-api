# frozen_string_literal: true

module SignIn
  module Webauthn
    module Authentication
      class OptionsGenerator
        CHALLENGE_TTL     = 5.minutes
        CACHE_KEY_PREFIX  = 'webauthn:auth'

        def initialize(credential_email: nil)
          @credential_email = credential_email&.strip&.downcase
        end

        def perform
          options = WebAuthn::Credential.options_for_get(**pubkey_request_params)
          challenge_id = SecureRandom.uuid

          cache_authentication_challenge(options.challenge, challenge_id)

          [options, challenge_id]
        end

        private

        attr_reader :credential_email

        def pubkey_request_params
          params = {
            user_verification: 'required',
            rp_id: expected_rp_id
          }

          params[:allow] = webauthn_descriptors if credential_email.present?

          params
        end

        def cache_authentication_challenge(challenge, challenge_id)
          Rails.cache.write("#{CACHE_KEY_PREFIX}:#{challenge_id}", challenge, expires_in: CHALLENGE_TTL)
        end

        def expected_rp_id
          WebAuthn.configuration.rp_id
        end

        def user_verifications
          UserVerification.joins(:user_credential_email)
                          .where(user_credential_email: { credential_email: })
                          .where.not(webauthn_credential_id: nil)
        end

        def webauthn_descriptors
          ids = user_verifications
                .joins(:webauthn_credential)
                .where.not(webauthn_credential_id: nil)
                .pluck('webauthn_credentials.credential_id')

          ids.map do |cid|
            WebAuthn::PublicKeyCredentialDescriptor.new(
              type: 'public-key',
              id: Base64.urlsafe_decode64(cid)
            )
          end
        end
      end
    end
  end
end
