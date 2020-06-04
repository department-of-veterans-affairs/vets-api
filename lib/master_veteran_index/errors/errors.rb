# frozen_string_literal: true

module MasterVeteranIndex::Errors
  class Base < StandardError; end
  class RecordNotFound < MasterVeteranIndex::Errors::Base; end

  class ServiceError < MasterVeteranIndex::Errors::Base
    attr_reader :body
    def initialize(body = nil)
      @body = body
      super
    end
  end

  class FailedRequestError < MasterVeteranIndex::Errors::ServiceError; end
  class InvalidRequestError < MasterVeteranIndex::Errors::ServiceError; end
  class DuplicateRecords < MasterVeteranIndex::Errors::RecordNotFound; end
end
