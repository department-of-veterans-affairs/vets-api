# frozen_string_literal: true

require_relative '../base_service'
require 'common/exceptions/external/backend_service_exception'

module VAOS::V1
  class FHIRService < VAOS::BaseService
    STATSD_KEY_PREFIX = 'api.vaos.fhir'

    def perform(http_method, path, params = nil)
      super(http_method, path, params, headers)
    end

    private

    def config
      VAOS::V1::FHIRConfiguration.instance
    end

    def headers
      super.merge!('Content-Type' => 'application/json+fhir')
    end
  end
end
