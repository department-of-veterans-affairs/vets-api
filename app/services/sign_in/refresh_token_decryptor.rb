# frozen_string_literal: true

module SignIn
  class RefreshTokenDecryptor
    attr_reader :split_token_array

    def initialize(encrypted_refresh_token:)
      @split_token_array = split_encrypted_refresh_token(encrypted_refresh_token)
    end

    def perform
      decrypted_component = get_decrypted_component

      validate_token!(decrypted_component)

      SignIn::RefreshToken.new(
        session_handle: decrypted_component.session_handle,
        user_uuid: decrypted_component.user_uuid,
        parent_refresh_token_hash: decrypted_component.parent_refresh_token_hash,
        anti_csrf_token: decrypted_component.anti_csrf_token,
        nonce: decrypted_component.nonce,
        version: decrypted_component.version
      )
    end

    private

    def validate_token!(decrypted_component)
      raise SignIn::Errors::RefreshVersionMismatchError unless decrypted_component.version == version_from_split_token
      raise SignIn::Errors::RefreshNonceMismatchError unless decrypted_component.nonce == nonce_from_split_token
    end

    def get_decrypted_component
      decrypted_string = decrypt_refresh_token(split_token_array[SignIn::Constants::RefreshToken::ENCRYPTED_POSITION])
      deserialize_token(decrypted_string)
    end

    def nonce_from_split_token
      split_token_array[SignIn::Constants::RefreshToken::NONCE_POSITION]
    end

    def version_from_split_token
      split_token_array[SignIn::Constants::RefreshToken::VERSION_POSITION]
    end

    def split_encrypted_refresh_token(encrypted_refresh_token)
      encrypted_refresh_token.split('.', SignIn::Constants::RefreshToken::ENCRYPTED_ARRAY.length)
    end

    def decrypt_refresh_token(encrypted_part)
      message_encryptor.decrypt(encrypted_part)
    end

    def deserialize_token(decrypted_string)
      JSON.parse(decrypted_string, object_class: OpenStruct)
    end

    def message_encryptor
      KmsEncrypted::Box.new
    end
  end
end
