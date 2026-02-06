# frozen_string_literal: true

require 'common/exceptions/backend_service_exception'
require 'vets/shared_logging'

# Custom exception that maps BGS errors to error details defined in config/locales/exceptions.en.yml
module BGS
  class ServiceException < Common::Exceptions::BackendServiceException
    include Vets::SharedLogging

    def initialize(key, response_values = {}, original_status = nil, original_body = nil)
      super(key, response_values, original_status, original_body)
    end

    private

    def code
      @key.presence || 'unmapped_service_exception'
    end
  end
end
