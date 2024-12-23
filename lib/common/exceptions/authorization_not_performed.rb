# frozen_string_literal: true

require 'common/exceptions/service_error'

module Common
  module Exceptions
    # For when a controller has not performed an authorization using Pundit
    class AuthorizationNotPerformedError < ServiceError
    end
  end
end
