# frozen_string_literal: true

require 'common/client/configuration/rest'

module FacilitiesApi
  module V2
    module MobileCovid
      class Configuration < Common::Client::Configuration::REST
        def base_path
          Settings.lighthouse.facilities.hqva_mobile.url
        end

        def service_name
          'MobileDirectBooking'
        end

        def connection
          Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
            conn.use(:breakers, service_name:)
            conn.request :instrumentation, name: 'facilities.mobile_covid.v2.request.faraday'

            # Uncomment this if you want curlggg command equivalent or response output to log
            # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
            # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

            conn.response :raise_custom_error, error_prefix: service_name

            conn.adapter Faraday.default_adapter
          end
        end
      end
    end
  end
end
