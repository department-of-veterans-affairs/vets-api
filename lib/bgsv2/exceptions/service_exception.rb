# frozen_string_literal: true

require 'common/exceptions/backend_service_exception'

# Custom exception that maps BGS errors to error details defined in config/locales/exceptions.en.yml
module BGSV2
  class ServiceException < Common::Exceptions::BackendServiceException
    include SentryLogging

    def initialize(key, response_values = {}, original_status = nil, original_body = nil)
      super(key, response_values, original_status, original_body)
    end

    private

    def code
      @key.presence || 'unmapped_service_exception'
    end
  end
end
