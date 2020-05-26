# frozen_string_literal: true

require_relative '../base_service'
require 'common/exceptions/external/backend_service_exception'
require 'common/exceptions/internal/invalid_field_value'

module VAOS
  module V1
    # FHIR (DSTU 2) based REST service http://hl7.org/fhir/dstu2/http.html
    #
    # @example Create a service and fetch an Organization resource by id
    #   service = VAOS::V1::FHIRService.new(user, :Organization)
    #   response = service.read(987654)
    #
    class FHIRService < VAOS::BaseService
      STATSD_KEY_PREFIX = 'api.vaos.fhir'
      RESOURCES = %i[Appointment HealthcareService Location Organization Patient Schedule Slot].freeze

      def initialize(resource_type:, user: nil)
        unless RESOURCES.include?(resource_type)
          raise Common::Exceptions::InvalidFieldValue.new('resource_type', resource_type)
        end

        @resource_type = resource_type
        super(user) unless user.nil?
      end

      # The read interaction accesses the current contents of a resource.
      # The interaction is performed by an HTTP GET command.
      # http://hl7.org/fhir/dstu2/http.html#read
      #
      # @id id Integer the id of the resource
      #
      def read(id)
        perform(:get, "#{@resource_type}/#{id}")
      end

      # This interaction searches a set of resources based on some filter criteria.
      # The interaction can be performed by several different HTTP commands.
      # http://hl7.org/fhir/dstu2/http.html#search
      #
      # @query_string String the query to run on the resource
      #
      def search(query_string)
        query_string.blank? ? perform(:get, @resource_type.to_s) : perform(:get, "#{@resource_type}?#{query_string}")
      end

      private

      def perform(method, path)
        StatsD.increment("#{action_statsd_key(path)}.total")
        super(method, path, nil, headers)
      rescue => e
        StatsD.increment("#{action_statsd_key(path)}.failure")
        raise e
      end

      def action_statsd_key(path)
        caller = caller_locations(2, 1)[0].label
        resource = path.split('/').first.split('?').first.snakecase
        "#{STATSD_KEY_PREFIX}.#{caller}.#{resource}"
      end

      def config
        VAOS::V1::FHIRConfiguration.instance
      end

      def headers
        super.merge('Content-Type' => 'application/json+fhir')
      end
    end
  end
end
