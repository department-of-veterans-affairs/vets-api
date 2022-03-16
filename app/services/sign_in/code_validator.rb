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
      raise SignIn::Errors::CodeInvalidError unless code_container
      raise SignIn::Errors::CodeChallengeMismatchError unless code_challenge == code_container.code_challenge
      raise SignIn::Errors::GrantTypeValueError unless grant_type == Constants::Auth::GRANT_TYPE
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
      raise Errors::CodeVerifierMalformedError
    end
  end
end
