# frozen_string_literal: true

require 'kms_encrypted'
ENV['KMS_KEY_ID'] ||= 'insecure-test-key' if Rails.env.development? || Rails.env.test?
KmsEncrypted.key_id = ENV.fetch('KMS_KEY_ID', nil)

Rails.application.reloader.to_prepare do
  KmsEncrypted::Model.prepend KmsEncryptedModelPatch
end
