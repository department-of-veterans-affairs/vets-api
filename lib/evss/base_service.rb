# frozen_string_literal: true
module EVSS
  class BaseService
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
        req.body = body
      end
    end

    private

    # Uses HTTPClient adapter because headers need to be sent unmanipulated
    # Net/HTTP capitalizes headers
    def conn
      @conn ||= Faraday.new(@base_url, headers: @headers) do |faraday|
        faraday.options.timeout = @default_timeout
        faraday.response :json, content_type: /\bjson$/
        faraday.adapter  :httpclient
      end
    end
  end
end
