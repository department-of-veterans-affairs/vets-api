# frozen_string_literal: true

module SignIn
  class CodeValidator
    attr_reader :code, :code_verifier, :client_assertion, :client_assertion_type, :grant_type

    def initialize(code:, code_verifier:, client_assertion:, client_assertion_type:, grant_type:)
      @code = code
      @code_verifier = code_verifier
      @client_assertion = client_assertion
      @client_assertion_type = client_assertion_type
      @grant_type = grant_type
    end

    def perform
      validations
      validated_credential
    ensure
      code_container&.destroy
    end

    private

    def validations
      validate_code_container
      validate_grant_type
      if client_config.pkce?
        validate_code_challenge
      else
        validate_client_assertion
      end
    end

    def validate_client_assertion
      SignIn::ClientAssertionValidator.new(client_assertion:, client_assertion_type:, client_config:).perform
    end

    def validate_code_container
      raise Errors::CodeInvalidError.new message: 'Code is not valid' unless code_container
    end

    def validate_code_challenge
      if code_challenge != code_container.code_challenge
        raise Errors::CodeChallengeMismatchError.new message: 'Code Verifier is not valid'
      end
    end

    def validate_grant_type
      if grant_type != Constants::Auth::AUTH_CODE
        raise Errors::GrantTypeValueError.new message: 'Grant Type is not valid'
      end
    end

    def user_verification
      @user_verification ||= UserVerification.find(code_container.user_verification_id)
    end

    def code_challenge
      @code_challenge ||= remove_base64_padding(Digest::SHA256.base64digest(code_verifier))
    end

    def code_container
      @code_container ||= CodeContainer.find(code)
    end

    def remove_base64_padding(data)
      Base64.urlsafe_encode64(Base64.urlsafe_decode64(data.to_s), padding: false)
    rescue ArgumentError
      raise Errors::CodeVerifierMalformedError.new message: 'Code Verifier is malformed'
    end

    def validated_credential
      @validated_credential ||= ValidatedCredential.new(user_verification:,
                                                        credential_email: code_container.credential_email,
                                                        client_config:)
    end

    def client_config
      @client_config ||= SignIn::ClientConfig.find_by(client_id: code_container.client_id)
    end
  end
end
