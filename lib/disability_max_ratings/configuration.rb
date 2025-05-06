# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_custom_error'

module DisabilityMaxRatings
  class Configuration < Common::Client::Configuration::REST
    self.open_timeout = Settings.disability_max_ratings_api.open_timeout
    self.read_timeout = Settings.disability_max_ratings_api.read_timeout

    def base_path
      Settings.disability_max_ratings_api.url.to_s
    end

    def service_name
      'DisabilityMaxRatingsApiClient'
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
