# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/ppms_parser'
require 'facilities/ppms/do_not_encoder'

module Facilities
  module PPMS
    module V0
      class Configuration < Common::Client::Configuration::REST
        self.open_timeout = Settings.ppms.open_timeout
        self.read_timeout = Settings.ppms.read_timeout
        def base_path
          Settings.ppms.url
        end

        def service_name
          'PPMS'
        end

        def connection
          Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
            conn.use :breakers
            conn.use :instrumentation, name: 'facilities.ppms.request.faraday'
            conn.options.params_encoder = Facilities::PPMS::DoNotEncoder

            # Uncomment this if you want curl command equivalent or response output to log
            # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
            # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

            conn.response :raise_error, error_prefix: service_name
            conn.response :ppms_parser

            conn.adapter Faraday.default_adapter
          end
        end
      end
    end
  end
end
