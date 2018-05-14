# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/facility_parser'
require 'typhoeus'
require 'typhoeus/adapters/faraday'

module Facilities
  class ServiceException < Common::Exceptions::BackendServiceException; end
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

        conn.response :raise_error, error_prefix: service_name
        conn.response :facility_parser

        conn.adapter Faraday.default_adapter
      end
    end
  end
end
