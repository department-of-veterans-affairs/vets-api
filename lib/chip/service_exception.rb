# frozen_string_literal: true

require 'common/exceptions/backend_service_exception'

module Chip
  class ServiceException < Common::Exceptions::BackendServiceException
    include SentryLogging

    UNMAPPED_KEY = 'unmapped_service_exception'

    def initialize(key, response_values = {}, original_status = nil, original_body = nil)
      super(key, response_values, original_status, original_body)
    end

    private

    def code
      if @key.present? && I18n.exists?("chip.exceptions.#{@key}")
        @key
      else
        UNMAPPED_KEY
      end
    end

    def i18n_key
      "chip.exceptions.#{code}"
    end
  end
end
