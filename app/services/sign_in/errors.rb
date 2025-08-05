# frozen_string_literal: true

module SignIn
  module Errors
    class StandardError < StandardError
      attr_reader :code

      def initialize(message:, code: Constants::ErrorCode::INVALID_REQUEST)
        @code = code
        super(message)
      end
    end

    class AccessDeniedError < StandardError; end
    class AccessTokenExpiredError < StandardError; end
    class AccessTokenMalformedJWTError < StandardError; end
    class AccessTokenSignatureMismatchError < StandardError; end
    class AccessTokenUnauthenticatedError < StandardError; end
    class AntiCSRFMismatchError < StandardError; end
    class AssertionExpiredError < StandardError; end
    class AssertionMalformedJWTError < StandardError; end
    class AssertionSignatureMismatchError < StandardError; end
    class AttributeMismatchError < StandardError; end
    class ClientAssertionAttributesError < StandardError; end
    class ClientAssertionExpiredError < StandardError; end
    class ClientAssertionInvalidError < StandardError; end
    class ClientAssertionMalformedJWTError < StandardError; end
    class ClientAssertionSignatureMismatchError < StandardError; end
    class ClientAssertionTypeInvalidError < StandardError; end
    class CodeChallengeMalformedError < StandardError; end
    class CodeChallengeMethodMismatchError < StandardError; end
    class CodeChallengeMismatchError < StandardError; end
    class CodeInvalidError < StandardError; end
    class CodeVerifierMalformedError < StandardError; end
    class CredentialLockedError < StandardError; end
    class CredentialMissingAttributeError < StandardError; end
    class CredentialProviderError < StandardError; end
    class GrantTypeValueError < StandardError; end
    class InvalidAccessTokenAttributeError < StandardError; end
    class InvalidAcrError < StandardError; end
    class InvalidAudienceError < StandardError; end
    class InvalidClientConfigError < StandardError; end
    class InvalidCredentialLevelError < StandardError; end
    class InvalidScope < StandardError; end
    class InvalidServiceAccountScope < StandardError; end
    class InvalidSSORequestError < StandardError; end
    class InvalidTokenError < StandardError; end
    class InvalidTokenTypeError < StandardError; end
    class InvalidTypeError < StandardError; end
    class LogingovRiscEventHandlerError < StandardError; end
    class LogoutAuthorizationError < StandardError; end
    class MalformedParamsError < StandardError; end
    class MHVMissingMPIRecordError < StandardError; end
    class MissingParamsError < StandardError; end
    class MPILockedAccountError < StandardError; end
    class MPIMalformedAccountError < StandardError; end
    class MPIUserCreationFailedError < StandardError; end
    class RefreshNonceMismatchError < StandardError; end
    class RefreshTokenDecryptionError < StandardError; end
    class RefreshTokenMalformedError < StandardError; end
    class RefreshVersionMismatchError < StandardError; end
    class ServiceAccountAssertionAttributesError < StandardError; end
    class ServiceAccountConfigNotFound < StandardError; end
    class SessionNotAuthorizedError < StandardError; end
    class SessionNotFoundError < StandardError; end
    class StateCodeInvalidError < StandardError; end
    class StatePayloadError < StandardError; end
    class StatePayloadMalformedJWTError < StandardError; end
    class StatePayloadSignatureMismatchError < StandardError; end
    class TermsOfUseNotAcceptedError < StandardError; end
    class TokenTheftDetectedError < StandardError; end
    class UnverifiedCredentialBlockedError < StandardError; end
    class UserAccountNotFoundError < StandardError; end
    class UserAttributesMalformedError < StandardError; end
  end
end
