# frozen_string_literal: true

module Vass
  module Errors
    class BaseError < StandardError; end

    class RedisError < BaseError; end
    class ValidationError < BaseError; end
    class AuthenticationError < BaseError; end
    class ServiceError < BaseError; end
    class VassApiError < BaseError; end
    class NotFoundError < BaseError; end
  end
end
