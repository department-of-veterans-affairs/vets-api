# frozen_string_literal: true

module Login
  module Errors
    class UserVerificationNotCreatedError < StandardError; end
    class CSPLockedError < StandardError; end
    class UnknownLoginTypeError < StandardError; end
  end
end
