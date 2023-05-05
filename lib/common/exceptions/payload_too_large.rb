# frozen_string_literal: true

require 'common/exceptions/service_error'

module Common
  module Exceptions
    # For when a service sends back a PayloadTooLarge error
    class PayloadTooLarge < ServiceError
    end
  end
end
