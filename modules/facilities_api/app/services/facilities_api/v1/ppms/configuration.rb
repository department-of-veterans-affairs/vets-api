# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_error'
require_relative 'middleware/ppms_parser'

module FacilitiesApi
  module V1
    module PPMS
      class Configuration < Common::Client::Configuration::REST
        self.open_timeout = Settings.ppms.open_timeout
        self.read_timeout = Settings.ppms.read_timeout
        def base_path
          if Flipper.enabled?(:facility_locator_ppms_use_secure_api)
            Settings.ppms.apim_url
          else
            Settings.ppms.url
          end
        end

        def service_name
          'PPMS'
        end

        def base_request_header
          if Flipper.enabled?(:facility_locator_ppms_use_secure_api)
            super.merge(Settings.ppms.api_keys.to_h.stringify_keys)
          else
            super
          end
        end

        def connection
          Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
            conn.use :breakers
            conn.use :instrumentation, name: 'facilities.ppms.request.faraday'

            # Uncomment this if you want curl command equivalent or response output to log
            # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
            # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

            conn.response :raise_error, error_prefix: service_name
            conn.use FacilitiesApi::V1::PPMS::Middleware::PPMSParser

            conn.adapter Faraday.default_adapter
          end
        end
      end
    end
  end
end
