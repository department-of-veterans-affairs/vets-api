# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_custom_error'
require 'lighthouse/facilities/middleware/errors'

module Lighthouse
  module Facilities
    class Configuration < Common::Client::Configuration::REST
      def base_path
        Settings.lighthouse.facilities.url
      end

      def service_name
        'Lighthouse_Facilities'
      end

      def self.base_request_headers
        super.merge('apiKey' => Settings.lighthouse.facilities.api_key)
      end

      def connection
        Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
          conn.use(:breakers, service_name:)
          conn.request :instrumentation, name: 'lighthouse.facilities.request.faraday'

          # Uncomment this if you want curl command equivalent or response output to log
          # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
          # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

          conn.response :raise_custom_error, error_prefix: service_name
          conn.response :lighthouse_facilities_errors

          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
