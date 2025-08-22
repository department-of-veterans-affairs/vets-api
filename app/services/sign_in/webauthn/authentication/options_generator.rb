# frozen_string_literal: true

module SignIn
  module Webauthn
    module Authentication
      class OptionsGenerator
        CHALLENGE_TTL = 5.minutes
        CACHE_KEY_PREFIX = 'webauthn:auth'

        def initialize(allow: nil)
          @allow = allow
        end

        def perform
          options = WebAuthn::Credential.options_for_get(**options_params)
          challenge_id = SecureRandom.uuid

          cache_authentication_challenge(options.challenge, challenge_id)

          [options, challenge_id]
        end

        private

        attr_reader :allow

        def options_params
          {
            allow:,
            user_verification: 'required'
          }.compact
        end

        def cache_authentication_challenge(challenge, challenge_id)
          Rails.cache.write("#{CACHE_KEY_PREFIX}:#{challenge_id}", challenge, expires_in: CHALLENGE_TTL)
        end
      end
    end
  end
end
