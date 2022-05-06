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
      user_account
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

    def user_account
      @user_account ||= UserAccount.find(code_container.user_account_uuid)
    end

    def code_challenge
      @code_challenge ||= remove_base64_padding(Digest::SHA256.base64digest(code_verifier))
    end

    def code_container
      @code_container ||= SignIn::CodeContainer.find(code)
    end

    def remove_base64_padding(data)
      Base64.urlsafe_encode64(Base64.urlsafe_decode64(data.to_s), padding: false)
    rescue ArgumentError
      raise Errors::CodeVerifierMalformedError, 'Code Verifier is malformed'
    end
  end
end
