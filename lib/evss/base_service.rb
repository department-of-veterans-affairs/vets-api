# frozen_string_literal: true
require_dependency 'evss/error_middleware'

module EVSS
  class BaseService
    SYSTEM_NAME = 'vets.gov'

    def initialize
      @default_timeout = 5 # seconds
    end

    protected

    def get(url)
      conn.get url
    end

    def post(url, body)
      conn.post url do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = body.to_json
      end
    end

    private

    # Uses HTTPClient adapter because headers need to be sent unmanipulated
    # Net/HTTP capitalizes headers
    def conn
      @conn ||= Faraday.new(@base_url, headers: @headers) do |faraday|
        faraday.options.timeout = @default_timeout
        faraday.use      EVSS::ErrorMiddleware
        faraday.use      Faraday::Response::RaiseError
        faraday.response :json, content_type: /\bjson$/
        faraday.adapter  :httpclient
      end
    end
  end
end
