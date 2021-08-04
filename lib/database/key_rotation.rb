# frozen_string_literal: true

module Database
  module KeyRotation
    attr_accessor :database_key

    def decrypting?(attribute)
      encrypted_attributes[attribute][:operation] == :decrypting
    end

    def encryption_key(_attribute)
      Settings.db_encryption_key
    end
  end
end
