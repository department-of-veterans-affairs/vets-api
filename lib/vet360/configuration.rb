# frozen_string_literal: true

require 'common/client/configuration/rest'
require_relative 'models/base'

module Vet360
  class Configuration < Common::Client::Configuration::REST
    def self.base_request_headers
      super.merge('cufSystemName' => Vet360::Models::Base::SOURCE_SYSTEM)
    end

    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use      :breakers
        faraday.use      Faraday::Response::RaiseError

        faraday.response :betamocks if mock_enabled?
        faraday.response :snakecase, symbolize: false
        faraday.response :json, content_type: /\bjson/ # ensures only json content types parsed
        faraday.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      false
    end
  end
end
