# frozen_string_literal: true

FitbitAPI.configure do |config|
  config.client_id       = Settings.dhp.fitbit.client_id
  config.client_secret   = Settings.dhp.fitbit.client_secret
  config.snake_case_keys = true
  config.symbolize_keys  = true
end

CODE_CHALLENGE = Settings.dhp.fitbit.code_challenge
CODE_VERIFIER = Settings.dhp.fitbit.code_verifier
