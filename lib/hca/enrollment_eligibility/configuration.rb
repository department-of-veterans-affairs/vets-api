# frozen_string_literal: true

module HCA
  module EnrollmentEligibility
    class Configuration < Common::Client::Configuration::SOAP
      def base_path
        Settings.hca.ee.endpoint
      end

      def service_name
        'HCA_EE'
      end

      def connection
        Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
          conn.use(:breakers, service_name:)
          conn.request :soap_headers
          conn.response :soap_parser
          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
