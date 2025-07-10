# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'veteran_enrollment_system/form1095_b/configuration'

module VeteranEnrollmentSystem
  module Form1095B
    ##
    # Service class for fetching Form 1095-B data from the enrollment system.
    # This service handles communication with the upstream enrollment system to retrieve
    # Form 1095-B tax forms for veterans.
    #
    # @example Fetch form data for a specific user and tax year
    #   service = VeteranEnrollmentSystem::Form1095B::Service.new(user)
    #   form_data = service.get_form_by_icn(icn: '1234', tax_year: 2023)
    #
    class Service < Common::Client::Base
      include Common::Client::Concerns::Monitoring
      include SentryLogging

      configuration VeteranEnrollmentSystem::Form1095B::Configuration
      STATSD_KEY_PREFIX = 'api.form1095b_enrollment'

      # @param user [User] The user for whom to fetch Form 1095-B data
      def initialize(user = nil)
        @user = user
        super()
      end

      # Fetch Form 1095-B data by ICN from the enrollment system
      #
      # @param icn [String] The ICN of the veteran
      # @param tax_year [Integer] The tax year for which to fetch the form
      # @return [Hash] The form data returned by the enrollment system
      # @raise [Common::Exceptions::BackendServiceException] If the upstream service returns an error
      def get_form_by_icn(icn:, tax_year:)
        with_monitoring do
          path = "ves-ee-summary-svc/form1095b/#{icn}/#{tax_year}"
          response = perform(:get, path, {})
          response.body
        end
      end
    end
  end
end
