# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_custom_error'
require 'common/client/middleware/response/facility_parser'

module Facilities
  module Gis
    # Configuration class used to setup the environment used by client
    class MetadataConfiguration < Common::Client::Configuration::REST
      def base_path
        Settings.locators.gis_base_path
      end

      def service_name
        'FL'
      end

      def connection
        Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
          conn.use :breakers
          conn.request :json

          conn.response :betamocks if Settings.locators.mock_gis
          conn.response :raise_custom_error, error_prefix: service_name

          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
