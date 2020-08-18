# frozen_string_literal: true

module CovidResearch
  module Volunteer
    class FormCryptoService
      extend AttrEncrypted
      attr_encrypted :submission, key: Settings.db_encryption_key

      def decrypt_redis_format(redis_format)
        decrypt_form(redis_format.form_data, redis_format.iv)
      end

      def decrypt_form(form_data, iv)
        @encrypted_submission = form_data
        @encrypted_submission_iv = iv

        submission
      end

      def encrypt_form(form_data)
        # AttrEncrypted won't fire without explicit self
        self.submission = form_data

        {
          form_data: encrypted_submission,
          iv: encrypted_submission_iv
        }
      end

      def encrypt_and_encode(form_data)
        parts = encrypt_form(form_data)

        parts[:form_data] = Base64.encode64(parts[:form_data])
        parts[:iv] = Base64.encode64(parts[:iv])

        parts
      end
    end
  end
end
