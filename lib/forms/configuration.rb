# frozen_string_literal: true

require 'common/client/configuration/rest'

module Forms
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = 30

    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use      :breakers
        faraday.use      Faraday::Response::RaiseError

        faraday.response :snakecase, symbolize: false
        faraday.response :json, content_type: /\bjson/ # ensures only json content types parsed
        faraday.adapter Faraday.default_adapter
      end
    end

    def self.base_request_headers
      super.merge('apiKey' => Settings.lighthouse.api_key)
    end

    def base_path
      "#{Settings.lighthouse.url}va_forms/v0/forms"
    end

    def service_name
      'VaForms'
    end
  end
end
