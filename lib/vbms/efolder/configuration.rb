# frozen_string_literal: true

module VBMS
  module Efolder
    class Configuration < Common::Client::Configuration::Base # TODO
      def base_path
        Settings.vbms.url
      end

      def service_name
        'vbms_efolder'
      end

      # we are using the connect_vbms gem for interaction with the vbms service, but we will define a connection
      # here to add breakers functionality.
      # TODO: how to check vbms for service outage or does the gem do this?
      def connection
        Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use :breakers
          faraday.request :json

          faraday.response :raise_error, error_prefix: service_name
          faraday.response :betamocks if mock_enabled?
          faraday.response :json
          faraday.adapter Faraday.default_adapter
        end
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        [true, 'true'].include?(Settings.vbms.efolder.mock)
      end
    end
  end

end