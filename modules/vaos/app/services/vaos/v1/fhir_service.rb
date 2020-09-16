# frozen_string_literal: true

require_relative '../base_service'
require 'common/exceptions/backend_service_exception'
require 'common/exceptions/invalid_field_value'

module VAOS
  module V1
    # FHIR (DSTU 2) based REST service http://hl7.org/fhir/dstu2/http.html
    #
    # @example Create a service and fetch an Organization resource by id
    #   service = VAOS::V1::FHIRService.new(user, :Organization)
    #   response = service.read(987654)
    #
    class FHIRService < VAOS::SessionService
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

      # The create interaction creates a resource based on the FHIR resource passed in the request body.
      # The interaction is performed by and HTTP POST command.
      # http://hl7.org/fhir/dstu2/http.html#create
      #
      # @body JSON string containing POST request values in the body key.
      #
      def create(body: nil)
        perform(:post, @resource_type.to_s, body)
      end

      # The update interaction creates a new current version for an existing resource or creates an initial verson
      # if no resource already exists for the given id.
      # The interaction is performed by the HTTP PUT command.
      # http://hl7.org/fhir/dstu2/http.html#update
      #
      # @id The id of the resource to update (must match the id continained in the put body)
      # @body The resource with an id element that has the same value as the id in the URL.
      #
      def update(id: nil, body: nil)
        perform(:put, "#{@resource_type}/#{id}", body)
      end

      private

      def perform(method, path, params = nil)
        StatsD.increment("#{action_statsd_key(path)}.total")
        super(method, path, params, headers)
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
