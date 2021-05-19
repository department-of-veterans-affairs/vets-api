# frozen_string_literal: true

require 'common/client/configuration/rest'

module FacilitiesApi
  module V1
    module MobileCovid
      class Configuration < Common::Client::Configuration::REST
        def base_path
          Settings.hqva_mobile.url
        end

        def service_name
          'MobileDirectBooking'
        end

        def connection
          Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
            conn.use :breakers
            conn.use :instrumentation, name: 'facilities.mobile_covid.request.faraday'

            # Uncomment this if you want curlggg command equivalent or response output to log
            # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
            # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

            conn.response :raise_error, error_prefix: service_name

            conn.adapter Faraday.default_adapter
          end
        end
      end
    end
  end
end
