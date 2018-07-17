# frozen_string_literal: true

module IHub
  module Appointments
    class Configuration < Common::Client::Configuration::REST
      def base_path
        "#{Settings.ihub.url}/api/Appointments/1.0/json/ftpCRM/"
      end

      def service_name
        'iHub/Appointments'
      end

      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use      :breakers
          faraday.use      Faraday::Response::RaiseError

          faraday.response :betamocks if mock_enabled?
          faraday.response :snakecase, symbolize: false
          faraday.response :json, content_type: /\bjson/ # ensures only json content types parsed
          faraday.adapter Faraday.default_adapter
        end
      end

      def mock_enabled?
        Settings.ihub.appointments.mock || false
      end
    end
  end
end
