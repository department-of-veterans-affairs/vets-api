# frozen_string_literal: true

module Database
  module KeyRotation
    def decrypting?(attribute)
      encrypted_attributes[attribute][:operation] == :decrypting
    end

    def encryption_key(attribute)
      Settings.db_encryption_key
    end
  end
end
