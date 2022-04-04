# frozen_string_literal: true

FitbitAPI.configure do |config|
  config.client_id       = Settings.dhp.fitbit.client_id
  config.client_secret   = Settings.dhp.fitbit.client_secret
  config.snake_case_keys = true
  config.symbolize_keys  = true
end

PKCE_CHALLENGE = PkceChallenge.challenge(char_length: 128)
CODE_CHALLENGE = PKCE_CHALLENGE.code_challenge.freeze
CODE_VERIFIER = PKCE_CHALLENGE.code_verifier.freeze
