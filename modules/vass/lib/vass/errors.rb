# frozen_string_literal: true

module Vass
  module Errors
    # Error keys for service exceptions
    ERROR_KEY_VASS_ERROR = 'VASS_ERROR'
    ERROR_KEY_CLIENT_ERROR = 'VASS_CLIENT_ERROR'
    ERROR_KEY_TIMEOUT = 'VASS_TIMEOUT'

    class BaseError < StandardError; end

    class RedisError < BaseError; end
    class ValidationError < BaseError; end

    class AuthenticationError < BaseError
      # Safe message constants for authentication errors.
      # These are the only messages that will be rendered to clients.
      MISSING_TOKEN = 'Missing authentication token'
      EXPIRED_TOKEN = 'Token has expired'
      INVALID_TOKEN = 'Invalid or malformed token'
      REVOKED_TOKEN = 'Token is invalid or already revoked'

      SAFE_MESSAGES = [MISSING_TOKEN, EXPIRED_TOKEN, INVALID_TOKEN, REVOKED_TOKEN].freeze
    end

    class ServiceError < BaseError; end
    class VassApiError < BaseError; end
    class NotFoundError < BaseError; end
    class RateLimitError < BaseError; end
    class IdentityValidationError < BaseError; end
    class MissingContactInfoError < BaseError; end
    class AuditLogError < BaseError; end
    class SerializationError < BaseError; end
    class EncryptionError < BaseError; end
    class DecryptionError < BaseError; end
    class ConfigurationError < BaseError; end
  end
end
