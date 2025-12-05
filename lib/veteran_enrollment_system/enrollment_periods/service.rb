# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'veteran_enrollment_system/enrollment_periods/configuration'
require 'veteran_enrollment_system/error_handling'

module VeteranEnrollmentSystem
  module EnrollmentPeriods
    ##
    # Service class for fetching enrollment periods data from the enrollment system.
    # This service handles communication with the upstream enrollment system to retrieve
    # enrollment periods for users.
    #
    # @example Fetch enrollment periods data for a specific user
    #   service = VeteranEnrollmentSystem::EnrollmentPeriods::Service.new(user)
    #   enrollment_periods = service.get_enrollment_periods(icn: '1234')
    #
    class Service < Common::Client::Base
      include Common::Client::Concerns::Monitoring
      include VeteranEnrollmentSystem::ErrorHandling

      configuration VeteranEnrollmentSystem::EnrollmentPeriods::Configuration
      STATSD_KEY_PREFIX = 'api.enrollment_periods'

      # Fetch enrollment periods by ICN from the enrollment system
      #
      # @param icn [String] The ICN of the veteran
      # @return [Array] The enrollment periods data returned by the enrollment system
      # @raise [Common::Exceptions::BackendServiceException] If the upstream service returns an error
      def get_enrollment_periods(icn:)
        with_monitoring do
          path = "ves-ee-summary-svc/enrollment-periods/person/#{icn}"
          response = perform(:get, path, {})
          if response.status == 200
            response.body['data']['mecPeriods']
          else
            raise_error(response, statsd_key_prefix: STATSD_KEY_PREFIX, operation: 'get_enrollment_periods')
          end
        end
      rescue => e
      # specs show that this is duplicative
      # StatsD.increment("#{STATSD_KEY_PREFIX}.get_enrollment_periods.failed")
        Rails.logger.error(
          "get_enrollment_periods failed: #{e.respond_to?(:errors) ? e.errors.first[:detail] : e.message}"
        )
        raise e
      end
    end
  end
end
