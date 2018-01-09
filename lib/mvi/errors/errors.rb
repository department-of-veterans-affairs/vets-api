# frozen_string_literal: true

module MVI
  module Errors
    class ServiceError < StandardError
    end
    class RequestFailureError < MVI::Errors::ServiceError
    end
    class InvalidRequestError < MVI::Errors::ServiceError
    end
    class RecordNotFound < StandardError
    end
  end
end
