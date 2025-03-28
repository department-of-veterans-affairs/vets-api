# frozen_string_literal: true

require 'common/client/configuration/rest'

module Apps
  ##
  # HTTP client configuration for the {Apps::Client},
  # sets the base path, the base request headers, and a service name for breakers and metrics.
  #
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = 30

    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use      Faraday::Response::RaiseError

        faraday.response :snakecase, symbolize: false
        faraday.response :json, content_type: /\bjson/ # ensures only json content types parsed
        faraday.adapter Faraday.default_adapter
      end
    end

    ##
    # @return [Hash] The basic headers required for any Apps API call.
    #
    def self.base_request_headers
      super.merge('apikey' => Settings.directory.key)
    end

    ##
    # @return [String] Base path for apps URLs.
    #
    def base_path
      Settings.directory.url
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'APPS'
    end
  end
end
