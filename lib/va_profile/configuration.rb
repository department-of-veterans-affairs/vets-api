# frozen_string_literal: true

require 'common/client/configuration/rest'
require_relative 'models/base'

module VAProfile
  class Configuration < Common::Client::Configuration::REST
    SETTINGS = Rails.env.production? ? Settings.va_profile : Settings.vet360

    def self.base_request_headers
      super.merge('cufSystemName' => VAProfile::Models::Base::SOURCE_SYSTEM)
    end

    def connection
      ssl_enabled = Rails.env.production?
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options,
                                       ssl: { verify: ssl_enabled }) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use      Faraday::Response::RaiseError

        faraday.response :snakecase, symbolize: false
        faraday.response :json, content_type: /\bjson/ # ensures only json content types parsed
        faraday.response :betamocks if mock_enabled?
        faraday.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      false
    end
  end
end
