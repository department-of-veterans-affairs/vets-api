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
    class AuthenticationError < BaseError; end
    class ServiceError < BaseError; end
    class VassApiError < BaseError; end
    class NotFoundError < BaseError; end
  end
end
