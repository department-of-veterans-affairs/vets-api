# frozen_string_literal: true

module CovidResearch
  module Volunteer
    class FormCryptoService
      attr_reader :lockbox

      def initialize
        @lockbox = Lockbox.new(key: Settings.lockbox.master_key,
                               previous_versions: [{ key: Settings.lockbox.previous_master_key }], encode: true)
      end

      # @param form_data [String] encrypted form data
      # @return [String] decrypted raw JSON form submission
      def decrypt_form(form_data)
        lockbox.decrypt(form_data)
      end

      # @param form_data [String] unencrypted form data (raw JSON data)
      # @return [Hash] a Hash with the encrypted form data (at `:form_data`) and the iv used to encrypt it (at `:iv`)
      def encrypt_form(form_data)
        {
          form_data: lockbox.encrypt(form_data)
        }
      end
    end
  end
end
