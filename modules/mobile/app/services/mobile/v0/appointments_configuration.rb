# frozen_string_literal: true

module Mobile
  module V0
    # Configuration for the Mobile::V0::AppointmentsService A singleton class that returns
    # a connection that can make parallel requests
    #
    # @example set the configuration in the service
    #   configuration Mobile::V0::Configuration
    #
    class Configuration < VAOS::Configuration

      # Service name for breakers integration
      # @return String the service name
      #
      def service_name
        'MobileAppointments'
      end
      
      # Faraday connection object with breakers, snakecase and json response middleware
      # @return Faraday::Connection connection to make http calls
      #
      def connection
        @connection ||= Faraday.new(
          base_path, headers: base_request_headers, request: request_options, ssl: ssl_options
        ) do |conn|
          conn.use :breakers
          conn.use Faraday::Response::RaiseError
          conn.response :snakecase
          conn.response :json, content_type: /\bjson$/
          conn.adapter :typhoeus
        end
      end
    end
  end
end
