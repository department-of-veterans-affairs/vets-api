# frozen_string_literal: true

require 'dgi/configuration'
require 'faraday/multipart'

module MebApi
  module DGI
    module Toe
      class Configuration < Common::Client::Configuration::REST
        def base_path
          Settings.dgi.vets.url.to_s
        end

        def connection
          @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
            faraday.use(:breakers, service_name:)
            faraday.use Faraday::Response::RaiseError

            faraday.request :multipart
            faraday.response :betamocks if mock_enabled?
            faraday.adapter Faraday.default_adapter
          end
        end

        # Change this once we know where we need to call
        # Using this for testing purpose.
        def service_name
          'DGI/Letters'
        end

        def mock_enabled?
          Settings.dgi.vets.mock || false
        end
      end
    end
  end
end
