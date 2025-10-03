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
    # @example Fetch form data for a specific user and tax year
    #   service = VeteranEnrollmentSystem::EnrollmentPeriods::Service.new(user)
    #   enrollment_periods = service.get_form_by_icn(icn: '1234')
    #
    class Service < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      configuration VeteranEnrollmentSystem::EnrollmentPeriods::Configuration
      STATSD_KEY_PREFIX = 'api.enrollment_periods'

      # Fetch enrollment periods by ICN from the enrollment system
      #
      # @param icn [String] The ICN of the veteran
      # @return [Hash] The form data returned by the enrollment system
      # @raise [Common::Exceptions::BackendServiceException] If the upstream service returns an error
      def get_enrollment_periods(icn:)
        with_monitoring do
          path = "ves-ee-summary-svc/enrollment-periods/person/#{icn}"
          response = perform(:get, path, {})
          response.body
        end
      end
    end
  end
end
