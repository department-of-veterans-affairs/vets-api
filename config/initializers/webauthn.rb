# frozen_string_literal: true

WebAuthn.configure do |config|
  config.origin = Settings.webauthn.origin # per environment

  # Relying Party name for display purposes
  config.rp_name = 'VA.gov'

  config.rp_id = Settings.webauthn.rp_id

  config.encoding = :base64url

  config.algorithms << 'ES256'
end
