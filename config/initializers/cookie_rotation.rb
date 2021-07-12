# frozen_string_literal: true

Rails.application.config.action_dispatch.cookies_rotations.tap do |cookies|
  config = Rails.application.config
  salt = config.action_dispatch.authenticated_encrypted_cookie_salt
  encrypted_cookie_cipher = config.action_dispatch.encrypted_cookie_cipher || 'aes-256-gcm'

  key_generator = ActiveSupport::KeyGenerator.new(Settings.old_secret_key_base, iterations: 1000)

  key_len = ActiveSupport::MessageEncryptor.key_len(encrypted_cookie_cipher)
  secret = key_generator.generate_key(salt, key_len)
  cookies.rotate :encrypted, secret
end
