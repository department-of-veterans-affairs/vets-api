# frozen_string_literal: true

module SignIn
  class RefreshTokenEncryptor
    attr_reader :refresh_token, :version, :nonce

    def initialize(refresh_token:)
      @refresh_token = refresh_token
      validate_input
      @version = refresh_token.version
      @nonce = refresh_token.nonce
    end

    def perform
      encrypted_refresh_token = serialize_and_encrypt_refresh_token
      build_refresh_token_string(encrypted_refresh_token)
    end

    private

    def validate_input
      unless refresh_token.version && refresh_token.nonce
        raise Errors::RefreshTokenMalformedError.new message: 'Refresh token is malformed'
      end
    end

    def build_refresh_token_string(encrypted_refresh_token)
      string_array = []
      string_array[Constants::RefreshToken::ENCRYPTED_POSITION] = encrypted_refresh_token
      string_array[Constants::RefreshToken::NONCE_POSITION] = nonce
      string_array[Constants::RefreshToken::VERSION_POSITION] = version
      string_array.join('.')
    end

    def serialize_and_encrypt_refresh_token
      serialized_refresh_token = refresh_token.to_json
      message_encryptor.encrypt(serialized_refresh_token)
    end

    def message_encryptor
      KmsEncrypted::Box.new
    end
  end
end
