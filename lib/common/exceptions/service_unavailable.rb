# frozen_string_literal: true

require 'common/exceptions/service_error'

module Common
  module Exceptions
    class ServiceUnavailable < ServiceError
    end
  end
end
