# frozen_string_literal: true

module SignIn
  class CodeValidator
    attr_reader :code, :code_verifier, :grant_type

    def initialize(code:, code_verifier:, grant_type:)
      @code = code
      @code_verifier = code_verifier
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
      raise SignIn::Errors::CodeInvalidError, 'Code is not valid' unless code_container
      if code_challenge != code_container.code_challenge
        raise SignIn::Errors::CodeChallengeMismatchError, 'Code Verifier is not valid'
      end
      raise SignIn::Errors::GrantTypeValueError, 'Grant Type is not valid' if grant_type != Constants::Auth::GRANT_TYPE
    end

    def user_verification
      @user_verification ||= UserVerification.find(code_container.user_verification_id)
    end

    def code_challenge
      @code_challenge ||= remove_base64_padding(Digest::SHA256.base64digest(code_verifier))
    end

    def code_container
      @code_container ||= SignIn::CodeContainer.find(code)
    end

    def credential_email
      @credential_email ||= code_container.credential_email
    end

    def remove_base64_padding(data)
      Base64.urlsafe_encode64(Base64.urlsafe_decode64(data.to_s), padding: false)
    rescue ArgumentError
      raise Errors::CodeVerifierMalformedError, 'Code Verifier is malformed'
    end

    def validated_credential
      @validated_credential ||= SignIn::ValidatedCredential.new(user_verification: user_verification,
                                                                credential_email: credential_email)
    end
  end
end
