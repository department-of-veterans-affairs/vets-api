# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/ppms_parser'

module Facilities
  class PPMSConfiguration < Common::Client::Configuration::REST
    self.open_timeout = 60
    self.read_timeout = 60
    def base_path
      Settings.ppms.url
    end

    def service_name
      'PPMS'
    end
    # ppms has strange behavior for certain url-encoded characters, no url-encoding works best
    class DoNotEncoder
      def self.encode(params)
        buffer = +''
        params.each do |key, value|
          buffer << "#{key}=#{value}&"
        end
        buffer.chop
      end
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.options.params_encoder = DoNotEncoder

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
