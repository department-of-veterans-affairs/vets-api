# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_custom_error'

module ContentionClassification
  class Configuration < Common::Client::Configuration::REST
    self.open_timeout = Settings.contention_classification_api.open_timeout
    self.read_timeout = Settings.contention_classification_api.read_timeout

    def base_path
      Settings.contention_classification_api.url.to_s
    end

    def service_name
      'ContentionClassificationApiClient'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use Faraday::Response::RaiseError
        faraday.response :json, content_type: /\bjson/
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
