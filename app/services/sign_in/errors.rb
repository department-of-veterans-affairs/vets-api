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
    class StateCodeInvalidError < StandardError; end
    class StatePayloadError < StandardError; end
    class StatePayloadSignatureMismatchError < StandardError; end
    class StatePayloadMalformedJWTError < StandardError; end
    class AttributeMismatchError < StandardError; end
    class GrantTypeValueError < StandardError; end
    class ClientAssertionTypeInvalidError < StandardError; end
    class ClientAssertionInvalidError < StandardError; end
    class ClientAssertionSignatureMismatchError < StandardError; end
    class ClientAssertionExpiredError < StandardError; end
    class ClientAssertionMalformedJWTError < StandardError; end
    class ClientAssertionAttributesError < StandardError; end
    class ServiceAccountAssertionAttributesError < StandardError; end
    class AssertionSignatureMismatchError < StandardError; end
    class AssertionExpiredError < StandardError; end
    class AssertionMalformedJWTError < StandardError; end
    class ServiceAccountConfigNotFound < StandardError; end
    class InvalidServiceAccountScope < StandardError; end
    class CodeInvalidError < StandardError; end
    class MalformedParamsError < StandardError; end
    class CodeVerifierMalformedError < StandardError; end
    class UserAccountNotFoundError < StandardError; end
    class SessionNotFoundError < StandardError; end
    class InvalidAcrError < StandardError; end
    class InvalidTypeError < StandardError; end
    class InvalidCredentialLevelError < StandardError; end
    class LogoutAuthorizationError < StandardError; end
    class UserAttributesMalformedError < StandardError; end
    class MPIUserCreationFailedError < StandardError; end
    class MPILockedAccountError < StandardError; end
    class MPIMalformedAccountError < StandardError; end
    class AccessDeniedError < StandardError; end
    class CredentialProviderError < StandardError; end
    class MHVMissingMPIRecordError < StandardError; end
    class UnverifiedCredentialBlockedError < StandardError; end
    class CredentialMissingAttributeError < StandardError; end
    class InvalidAccessTokenAttributeError < StandardError; end
    class TermsOfUseNotAcceptedError < StandardError; end
  end
end
