# frozen_string_literal: true

module Login
  module Errors
    class UserVerificationNotCreatedError < StandardError; end
    class UnknownLoginTypeError < StandardError; end
    class VerifiedUserAccountMismatch < StandardError; end
  end
end
