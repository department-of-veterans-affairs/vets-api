# frozen_string_literal: true

module InheritedProofing
  module Errors
    class AccessTokenSignatureMismatchError < StandardError; end
    class AccessTokenExpiredError < StandardError; end
    class AccessTokenMalformedJWTError < StandardError; end
    class AccessTokenMissingRequiredAttributesError < StandardError; end
    class UserNotFoundError < StandardError; end
    class MHVIdentityDataNotFoundError < StandardError; end
    class UserMissingAttributesError < StandardError; end
    class IdentityDocumentMissingError < StandardError; end
    class PreviouslyVerifiedError < StandardError; end
  end
end
