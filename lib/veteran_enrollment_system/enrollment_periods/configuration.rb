# frozen_string_literal: true

require 'veteran_enrollment_system/base_configuration'

module VeteranEnrollmentSystem
  module EnrollmentPeriods
    class Configuration < VeteranEnrollmentSystem::BaseConfiguration
      def self.api_key_path
        :enrollment_periods
      end

      def service_name
        'VeteranEnrollmentSystem/EnrollmentPeriods'
      end

      def connection
        Faraday.new(
          base_path,
          headers: base_request_headers,
          request: request_options
        ) do |conn|
          conn.use(:breakers, service_name:)
          conn.request :json
          conn.options.open_timeout = Settings.veteran_enrollment_system.open_timeout
          conn.options.timeout = Settings.veteran_enrollment_system.timeout
          conn.response :json_parser
          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
