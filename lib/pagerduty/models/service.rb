# frozen_string_literal: true

require 'common/models/base'
require 'common/models/attribute_types/iso8601_time'

module PagerDuty
  module Models
    class Service
      include ActiveModel::Validations
      include Virtus.model(nullify_blank: true)

      # 5 potential PagerDuty API `service#status` values
      # @see response schema from https://api-reference.pagerduty.com/#!/Services/get_services
      #
      ACTIVE      = 'active'
      WARNING     = 'warning'
      CRITICAL    = 'critical'
      DISABLED    = 'disabled'
      MAINTENANCE = 'maintenance'
      STATUSES    = [ACTIVE, WARNING, CRITICAL, MAINTENANCE, DISABLED].freeze

      attribute :service, String
      attribute :status, String
      attribute :last_incident_timestamp, Common::ISO8601Time

      validates :service, :status, presence: true
      validates :status, inclusion: { in: STATUSES }

      # Maps over the raw PagerDuty service hashes returned from PagerDuty's API GET /services
      # call, and converts those into PagerDuty::Models::Service objects
      #
      # @param services [Array<Hash>] An array of service hashes from PagerDuty's REST API
      # @return [Array<Service>] An array of PagerDuty::Models::Service objects
      # @see https://api-reference.pagerduty.com/#!/Services/get_services
      #
      def self.statuses_for(services)
        eligible!(services).map { |service| build!(service) }
      end

      class << self
        def eligible!(services)
          services.select do |service|
            name_present!(service)

            service['name'].start_with?('External:')
          end
        end

        def build!(service)
          external_service = Service.new(
            service: external_service_in(service),
            status: service['status'],
            last_incident_timestamp: service['last_incident_timestamp']
          )

          validate! external_service
        end

        def external_service_in(service)
          service['name'].split('External:').last.strip
        end

        def name_present!(service)
          raise Common::Exceptions::InvalidFieldValue.new('name', 'nil') if service['name'].blank?
        end

        def validate!(external_service)
          raise Common::Exceptions::ValidationErrors, external_service unless external_service.valid?

          external_service
        end
      end
    end
  end
end
