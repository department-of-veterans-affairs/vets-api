# frozen_string_literal: true

module SignIn
  module Errors
    ERROR_CODES = {
      unknown: '007'
    }.freeze

    class RefreshVersionMismatchError < StandardError; end
    class RefreshNonceMismatchError < StandardError; end
    class RefreshTokenMalformedError < StandardError; end
    class AccessTokenSignatureMismatchError < StandardError; end
    class AccessTokenMalformedJWTError < StandardError; end
    class AccessTokenExpiredError < StandardError; end
  end
end
