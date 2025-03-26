# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/vetext_errors'

module VEText
  class Configuration < Common::Client::Configuration::REST
    def base_path
      Settings.vetext_push.base_url
    end

    def service_name
      'VEText'
    end

    def connection
      @connection ||= Faraday.new(
        base_path, headers: base_request_headers, request: request_options
      ) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :authorization, :basic, Settings.vetext_push.user, Settings.vetext_push.pass
        conn.request :json
        conn.use Faraday::Response::RaiseError
        conn.response :snakecase
        conn.response :json, content_type: /\bjson$/
        conn.response :vetext_error
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
