# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'veteran_enrollment_system/enrollment_periods/configuration'

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

      configuration VeteranEnrollmentSystem::EnrollmentPeriods::Configuration

      STATSD_KEY_PREFIX = 'api.enrollment_periods'
      ERROR_MAP = {
        400 => Common::Exceptions::BadRequest,
        403 => Common::Exceptions::Forbidden,
        404 => Common::Exceptions::ResourceNotFound,
        500 => Common::Exceptions::ExternalServerInternalServerError,
        502 => Common::Exceptions::BadGateway,
        504 => Common::Exceptions::GatewayTimeout
      }.freeze

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
            raise_error(response)
          end
        end
      rescue => e
        Rails.logger.error(
          "get_enrollment_periods failed: #{e.respond_to?(:errors) ? e.errors.first[:detail] : e.message}"
        )
        raise e
      end

      private

      # Raises mapped error, logs, and increments StatsD for error cases.
      # Optionally accepts a statsd_key_prefix and operation name for metrics/logging.
      def raise_error(response)
        message = response.body['messages']&.pluck('description')&.join(', ') || response.body

        # Just in case the status is not in the ERROR_MAP, raise a BackendServiceException
        raise ERROR_MAP[response.status]&.new(detail: message) ||
              Common::Exceptions::BackendServiceException.new(nil, detail: message)
      end
    end
  end
end
