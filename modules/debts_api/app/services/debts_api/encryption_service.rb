# frozen_string_literal: true

module DebtsApi
  class EncryptionService
    def self.encrypt(value)
      encryptor.encrypt_and_sign(value)
    end

    def self.decrypt(encrypted_value)
      encryptor.decrypt_and_verify(encrypted_value)
    end

    private

    def self.encryptor
      key = Rails.application.key_generator.generate_key('pii_data', 32)
      ActiveSupport::MessageEncryptor.new(key)
    end
  end
end
