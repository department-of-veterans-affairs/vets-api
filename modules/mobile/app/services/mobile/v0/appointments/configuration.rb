# frozen_string_literal: true

module Mobile
  module V0
    module Appointments
      # Configuration for the Mobile::V0::Appointments::Service. A singleton class that returns
      # a connection that can make parallel requests
      #
      # @example set the configuration in the service
      #   configuration Mobile::V0::Appointments::Configuration
      #
      class Configuration < VAOS::Configuration
        # Service name for breakers integration
        # @return String the service name
        #
        def service_name
          'MobileAppointments'
        end

        # Faraday connection object with middleware defined and
        # the adapter set to typhoeus for parallel connections
        #
        # @return Faraday::Connection connection to make http calls
        #
        def parallel_connection
          Faraday.new(
            base_path, headers: base_request_headers, request: request_options
          ) do |conn|
            conn.use :breakers
            conn.request :camelcase
            conn.request :json

            conn.response :snakecase
            conn.response :json, content_type: /\bjson$/
            conn.response :vaos_errors
            conn.use :vaos_logging
            conn.adapter :typhoeus
          end
        end
      end
    end
  end
end
