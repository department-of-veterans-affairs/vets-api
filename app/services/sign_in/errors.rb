# frozen_string_literal: true

module SignIn
  module Errors
    class StandardError < StandardError; end
    class RefreshVersionMismatchError < StandardError; end
    class RefreshNonceMismatchError < StandardError; end
    class RefreshTokenMalformedError < StandardError; end
    class RefreshTokenDecryptionError < StandardError; end
    class AccessTokenSignatureMismatchError < StandardError; end
    class AccessTokenMalformedJWTError < StandardError; end
    class AccessTokenExpiredError < StandardError; end
    class AntiCSRFMismatchError < StandardError; end
    class SessionNotAuthorizedError < StandardError; end
    class TokenTheftDetectedError < StandardError; end
    class CodeChallengeMethodMismatchError < StandardError; end
    class CodeChallengeMalformedError < StandardError; end
    class CodeChallengeMismatchError < StandardError; end
    class StatePayloadError < StandardError; end
    class StatePayloadSignatureMismatchError < StandardError; end
    class StatePayloadMalformedJWTError < StandardError; end
    class GrantTypeValueError < StandardError; end
    class CodeInvalidError < StandardError; end
    class UserAttributesMalformedError < StandardError; end
    class MalformedParamsError < StandardError; end
    class AuthorizeInvalidType < StandardError; end
    class CodeVerifierMalformedError < StandardError; end
    class UserAccountNotFoundError < StandardError; end
    class SessionNotFoundError < StandardError; end
    class MPIUserCreationFailedError < StandardError; end
    class MPILockedAccountError < StandardError; end
    class MPIMalformedAccountError < StandardError; end
    class InvalidClientIdError < StandardError; end
    class InvalidAcrError < StandardError; end
    class InvalidTypeError < StandardError; end
    class InvalidCredentialLevelError < StandardError; end
    class InvalidCredentialInfoError < StandardError; end
    class LogoutAuthorizationError < StandardError; end
  end
end
