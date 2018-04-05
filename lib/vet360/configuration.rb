# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'typhoeus'
require 'typhoeus/adapters/faraday'

module Vet360
  # Configuration class used to setup the environment used by client
  class Configuration < Common::Client::Configuration::REST
    
    def base_path
      "#{Settings.vet360.host}/cuf/person/contact-information/v1/"
    end

    # def caching_enabled?
    #   Settings.vet360.collection_caching_enabled || false
    # end

    def service_name
      'Vet360'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        # conn.use :breakers
        conn.request :json

        # Uncomment this if you want curl command equivalent or response output to log
        # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
        # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

        conn.response :betamocks if Settings.vet360.mock
        conn.response :raise_error, error_prefix: service_name
        conn.response :json_parser

        conn.adapter Faraday.default_adapter
      end
    end

  end
end
