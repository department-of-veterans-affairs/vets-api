# frozen_string_literal: true

require 'common/client/configuration/rest'

module HomepageBanner
  ##
  # HTTP client configuration for the {Forms::Client},
  # sets the base path, the base request headers, and a service name for breakers and metrics.
  #
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = 30

    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use      :breakers
        faraday.use      Faraday::Response::RaiseError

        # faraday.response :text, content_type: /\text\/plain/ # ensures only json content types parsed
        faraday.adapter Faraday.default_adapter
      end
    end

    ##
    # @return [String] Base path for forms URLs.
    #
    def base_path
      Settings.homepage_banner.url
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'HomepageBanner'
    end
  end
end
