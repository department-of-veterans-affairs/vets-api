# frozen_string_literal: true

module CovidResearch
  module Volunteer
    class FormCryptoService
      extend AttrEncrypted
      attr_encrypted :submission, key: Settings.db_encryption_key

      # @param form_data [String] encrypted form data
      # @param iv [String] encrypted iv (for decrypting the form_data)
      # @return [String] decrypted raw JSON form submission
      def decrypt_form(form_data, iv)
        @encrypted_submission = form_data
        @encrypted_submission_iv = iv

        submission
      end

      # @param form_data [String] unencrypted form data (raw JSON data)
      # @return [Hash] a Hash with the encrypted form data (at `:form_data`) and the iv used to encrypt it (at `:iv`)
      def encrypt_form(form_data)
        # AttrEncrypted won't fire without explicit self
        self.submission = form_data

        {
          form_data: encrypted_submission,
          iv: encrypted_submission_iv
        }
      end
    end
  end
end
