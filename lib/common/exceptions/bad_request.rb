# frozen_string_literal: true

require 'common/exceptions/service_error'

module Common
  module Exceptions
    # For when an external service sends back an Internal Server Error
    class BadRequest < ServiceError
    end
  end
end
