# frozen_string_literal: true

require 'common/exceptions/external/backend_service_exception'

module MDOT
  class ServiceException < Common::Exceptions::BackendServiceException
    include SentryLogging

    def initialize(key = 'unmapped_service_exception', response_values = {}, original_status = nil, original_body = nil)
      super(key, response_values, original_status, original_body)
    end

    private

    def code
      if @key.present? && I18n.exists?("mdot.exceptions.#{@key}")
        @key
      else
        'unmapped_service_exception'
      end
    end

    def i18n_key
      "mdot.exceptions.#{code}"
    end
  end
end
