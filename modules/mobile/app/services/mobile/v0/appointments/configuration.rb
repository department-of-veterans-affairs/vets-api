# frozen_string_literal: true

module Mobile
  module V0
    module Appointments
      class Configuration < VAOS::Configuration
        def service_name
          'MobileAppointments'
        end

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
