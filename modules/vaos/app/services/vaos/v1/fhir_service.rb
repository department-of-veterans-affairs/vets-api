# frozen_string_literal: true

require_relative '../base_service'
require 'common/exceptions/external/backend_service_exception'
require 'common/exceptions/internal/invalid_field_value'

module VAOS::V1
  # FHIR (DSTU 2) based REST service http://hl7.org/fhir/dstu2/http.html
  #
  # @example Create a service and fetch an Organization resource by id
  #   service = VAOS::V1::FHIRService.new(user)
  #   response = service.read(:Organization, 987654)
  #
  class FHIRService < VAOS::BaseService
    STATSD_KEY_PREFIX = 'api.vaos.fhir'
    RESOURCES = %i(Appointment HealthcareService Location Organization Patient Schedule Slot)

    # The read interaction accesses the current contents of a resource.
    # The interaction is performed by an HTTP GET command.
    # http://hl7.org/fhir/dstu2/http.html#read
    #
    # @param resource_type Symbol the type of resource to read
    # @id id Integer the id of the resource
    #
    def read(resource_type, id)
      raise Common::Exceptions::InvalidFieldValue.new('resource_type', resource_type) unless RESOURCES.include?(resource_type)
      perform(:get, "#{resource_type}/#{id}", nil, headers)
    end

    # TODO: create http://hl7.org/fhir/dstu2/http.html#create
    # TODO: update http://hl7.org/fhir/dstu2/http.html#update
    # TODO: delete http://hl7.org/fhir/dstu2/http.html#delete

    private

    def config
      VAOS::V1::FHIRConfiguration.instance
    end

    def headers
      super.merge('Content-Type' => 'application/json+fhir')
    end
  end
end
