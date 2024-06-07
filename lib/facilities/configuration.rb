# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_custom_error'
require 'common/client/middleware/response/facility_validator'
require 'common/client/middleware/response/facility_parser'

module Facilities
  class Configuration < Common::Client::Configuration::REST
    def base_path
      Settings.locators.base_path
    end

    def service_name
      'FL'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.request :json

        # Uncomment this if you want curl command equivalent or response output to log
        # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
        # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

        conn.response :raise_custom_error, error_prefix: service_name
        conn.response :facility_parser
        conn.response :facility_validator

        conn.adapter Faraday.default_adapter
      end
    end
  end
end
