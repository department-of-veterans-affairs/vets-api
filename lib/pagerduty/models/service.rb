# frozen_string_literal: true

require 'common/models/base'
require 'common/models/attribute_types/iso8601_time'

module PagerDuty
  module Models
    class Service
      include ActiveModel::Validations
      include ActiveModel::Serialization
      include Virtus.model(nullify_blank: true)

      ACTIVE = 'active'
      WARNING = 'warning'
      CRITICAL = 'critical'
      MAINTENANCE = 'maintenance'
      DISABLED = 'disabled'
      STATUSES = [ACTIVE, WARNING, CRITICAL, MAINTENANCE, DISABLED].freeze

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
        eligible!(services).map do |pager_duty_service|
          external_service = build_service_for(pager_duty_service)

          validate! external_service
        end
      end

      class << self
        def eligible!(services)
          services.select do |pager_duty_service|
            name_present!(pager_duty_service)

            pager_duty_service['name'].start_with?('External:')
          end
        end

        def build_service_for(pager_duty_service)
          PagerDuty::Models::Service.new(
            service: external_service_in(pager_duty_service),
            status: pager_duty_service['status'],
            last_incident_timestamp: pager_duty_service['last_incident_timestamp']
          )
        end

        def external_service_in(pager_duty_service)
          pager_duty_service['name'].split('External:').last.strip
        end

        def name_present!(pager_duty_service)
          raise Common::Exceptions::InvalidFieldValue.new('name', 'nil') if pager_duty_service['name'].blank?
        end

        def validate!(external_service)
          raise Common::Exceptions::ValidationErrors.new(external_service) unless external_service.valid?

          external_service
        end
      end
    end
  end
end
