# frozen_string_literal: true

require_relative '../base_service'
require 'common/exceptions/external/backend_service_exception'

module VAOS::V1
  class FHIRService < VAOS::BaseService
    STATSD_KEY_PREFIX = 'api.vaos.fhir'
    RESOURCES = %i(Appointment HealthcareService Location Organization Patient Schedule Slot)

    def read(resource, id, params = nil)
      raise ArgumentError, "#{resource} is not a valid resource" unless RESOURCES.include? resource
      perform(:get, "#{resource}/#{id}", params, headers)
    end

    private

    def config
      VAOS::V1::FHIRConfiguration.instance
    end

    def headers
      super.merge('Content-Type' => 'application/json+fhir')
    end
  end
end
