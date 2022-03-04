# frozen_string_literal: true

module SignIn
  module Errors
    class RefreshVersionMismatchError < StandardError; end
    class RefreshNonceMismatchError < StandardError; end
    class RefreshTokenMalformedError < StandardError; end
  end
end
