# frozen_string_literal: true
module Common
  module Exceptions
    module MajorCodes
      # These are some basic HTTP error codes the API should support.
      BAD_REQUEST          = '400' # Request Header is invalid
      UNAUTHORIZED         = '401' # Invalid client credentials, expired token, etc
      FORBIDDEN            = '403' # Access denied *Important* - avoid using, prefer NOT_FOUND
      RECORD_NOT_FOUND     = '404' # Record not found *Important* - use this instead of forbidden for resources
      UNPROCESSABLE_ENTITY = '422' # ie. Model Validations
      SERVER_ERROR         = '500'
    end
  end
end
