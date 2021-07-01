# frozen_string_literal: true

require 'aes_256_cbc_encryptor'

Rails.application.reloader.to_prepare do
  # This sets the constant to be used for encryption and decryption of the cookie
  # it's important to do this at initialization level to ensure configuration issues are
  # caught at the time of deployment rather than "runtime"
  SSOEncryptor = Aes256CbcEncryptor.new(Settings.sso.cookie_key, Settings.sso.cookie_iv)
end
