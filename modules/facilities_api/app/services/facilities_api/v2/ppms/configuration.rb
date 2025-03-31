# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_custom_error'
require_relative 'middleware/ppms_parser'

module FacilitiesApi
  module V2
    module PPMS
      class Configuration < Common::Client::Configuration::REST
        self.open_timeout = Settings.ppms.open_timeout
        self.read_timeout = Settings.ppms.read_timeout
        def base_path
          Settings.ppms.url
        end

        def service_name
          'PPMS'
        end

        def base_request_headers
          super.merge(Settings.ppms.api_keys.to_h.stringify_keys)
        end

        def connection
          Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
            conn.use(:breakers, service_name:)
            conn.request :instrumentation, name: 'facilities.ppms.v2.request.faraday'

            # Uncomment this if you want curl command equivalent or response output to log
            # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
            # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

            conn.response :raise_custom_error, error_prefix: service_name
            conn.use FacilitiesApi::V2::PPMS::Middleware::PPMSParser

            conn.adapter Faraday.default_adapter
          end
        end
      end
    end
  end
end
