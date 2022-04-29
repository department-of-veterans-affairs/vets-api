# frozen_string_literal: true

module SignIn
  module Errors
    class RefreshVersionMismatchError < StandardError; end
    class RefreshNonceMismatchError < StandardError; end
    class RefreshTokenMalformedError < StandardError; end
    class AccessTokenSignatureMismatchError < StandardError; end
    class AccessTokenMalformedJWTError < StandardError; end
    class AccessTokenExpiredError < StandardError; end
    class AntiCSRFMismatchError < StandardError; end
    class SessionNotAuthorizedError < StandardError; end
    class TokenTheftDetectedError < StandardError; end
    class CodeChallengeMethodMismatchError < StandardError; end
    class CodeChallengeMalformedError < StandardError; end
    class CodeChallengeMismatchError < StandardError; end
    class GrantTypeValueError < StandardError; end
    class CodeInvalidError < StandardError; end
    class StateMismatchError < StandardError; end
    class UserAttributesMalformedError < StandardError; end
    class MalformedParamsError < StandardError; end
    class TokenSessionMismatch < StandardError; end
    class AuthorizeInvalidType < StandardError; end
    class CallbackInvalidType < StandardError; end
    class CodeVerifierMalformedError < StandardError; end
    class UserAccountNotFoundError < StandardError; end
    class SessionNotFoundError < StandardError; end
  end
end
