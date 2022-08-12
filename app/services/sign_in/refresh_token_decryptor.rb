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

      RefreshToken.new(
        session_handle: decrypted_component.session_handle,
        uuid: decrypted_component.uuid,
        user_uuid: decrypted_component.user_uuid,
        parent_refresh_token_hash: decrypted_component.parent_refresh_token_hash,
        anti_csrf_token: decrypted_component.anti_csrf_token,
        nonce: decrypted_component.nonce,
        version: decrypted_component.version
      )
    end

    private

    def validate_token!(decrypted_component)
      if decrypted_component.version != version_from_split_token
        raise Errors::RefreshVersionMismatchError, message: 'Refresh token version is invalid'
      end
      if decrypted_component.nonce != nonce_from_split_token
        raise Errors::RefreshNonceMismatchError, message: 'Refresh nonce is invalid'
      end
    end

    def get_decrypted_component
      decrypted_string = decrypt_refresh_token(split_token_array[Constants::RefreshToken::ENCRYPTED_POSITION])
      deserialize_token(decrypted_string)
    end

    def nonce_from_split_token
      split_token_array[Constants::RefreshToken::NONCE_POSITION]
    end

    def version_from_split_token
      split_token_array[Constants::RefreshToken::VERSION_POSITION]
    end

    def split_encrypted_refresh_token(encrypted_refresh_token)
      encrypted_refresh_token.split('.', Constants::RefreshToken::ENCRYPTED_ARRAY.length)
    end

    def decrypt_refresh_token(encrypted_part)
      message_encryptor.decrypt(encrypted_part)
    rescue KmsEncrypted::DecryptionError
      raise Errors::RefreshTokenDecryptionError, message: 'Refresh token cannot be decrypted'
    end

    def deserialize_token(decrypted_string)
      JSON.parse(decrypted_string, object_class: OpenStruct)
    end

    def message_encryptor
      KmsEncrypted::Box.new
    end
  end
end
