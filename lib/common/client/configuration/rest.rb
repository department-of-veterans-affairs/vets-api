# frozen_string_literal: true

require_relative 'base'

module Common
  module Client
    module Configuration
      ##
      # Configuration for REST based services.
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
      #       Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
      #         faraday.use :breakers
      #         faraday.request :json
      #
      #         faraday.response :raise_custom_error, error_prefix: service_name
      #         faraday.response :betamocks if mock_enabled?
      #         faraday.response :json
      #         faraday.adapter Faraday.default_adapter
      #       end
      #     end
      #   end
      #
      #   class MyService < Common::Client::Base
      #     configuration MyConfiguration
      #   end
      #
      class REST < Base
        self.request_types = %i[get put post delete].freeze
        self.base_request_headers = {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'User-Agent' => user_agent
        }.freeze
      end
    end
  end
end
