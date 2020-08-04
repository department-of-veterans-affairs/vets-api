# frozen_string_literal: true

require_relative 'base'

module Common
  module Client
    module Configuration
      ##
      # Configuration for SOAP based services.
      #
      # @example Create a configuration and use it in a service.
      #   class MyConfiguration < Common::Client::Configuration::REST
      #     def base_path
      #       Settings.my_service.url
      #     end
      #
      #     def service_name
      #       'MyServiceName'
      #     end
      #
      #     def connection
      #       Faraday.new(base_path, headers: base_request_headers, request: request_opts, ssl: ssl_opts) do |conn|
      #         conn.use :breakers
      #         conn.request :soap_headers
      #
      #         conn.response :soap_parser
      #         conn.response :betamocks if Settings.emis.mock
      #         conn.adapter Faraday.default_adapter
      #       end
      #     end
      #   end
      #
      #   class MyService < Common::Client::Base
      #     configuration MyConfiguration
      #   end
      #
      class SOAP < Base
        self.request_types = %i[post].freeze
        self.base_request_headers = {
          'Accept' => 'text/xml;charset=UTF-8',
          'Content-Type' => 'text/xml;charset=UTF-8',
          'User-Agent' => user_agent
        }.freeze
      end
    end
  end
end
