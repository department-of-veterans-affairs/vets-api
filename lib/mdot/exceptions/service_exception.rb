# frozen_string_literal: true

require 'common/exceptions/external/backend_service_exception'

module MDOT
  class ServiceException < Common::Exceptions::BackendServiceException
    include SentryLogging

    def initialize(exception, response_values = {}, original_status = nil, original_body = nil)
      @exception = exception
      super(exception.key, response_values, original_status, original_body)
    end

    private

    def code
      if @exception.key && I18n.exists?(@exception.i18n_key)
        @exception.key
      else
        'default_exception'
      end
    end

    def i18n_key
      @exception.i18n_key
    end
  end
end
