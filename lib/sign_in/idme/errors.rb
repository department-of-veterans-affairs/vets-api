# frozen_string_literal: true

module SignIn
  module Idme
    module Errors
      class JWTVerificationError < StandardError; end
      class JWTExpiredError < StandardError; end
      class JWTDecodeError < StandardError; end
      class JWEDecodeError < StandardError; end
    end
  end
end
