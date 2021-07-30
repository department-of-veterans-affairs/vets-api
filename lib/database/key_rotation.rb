# frozen_string_literal: true

module Database
  module KeyRotation
    def is_decrypting?(attribute)
      encrypted_attributes[attribute][:operation] == :decrypting
    end

    def encryption_key
      Settings.db_encryption_key
    end
  end
end
