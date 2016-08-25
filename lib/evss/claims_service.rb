module EVSS
  class ClaimsService
    def initialize(vaafi_headers = {})
      # TODO: Get base URI from env
      @base_url = "http://csraciapp6.evss.srarad.com:7003/wss-claims-services-web-3.1/rest"
      @headers = vaafi_headers
      @default_timeout = 5 # seconds
    end

    def claims
      conn.get "vbaClaimStatusService/getOpenClaims"
    end

    def create_intent_to_file
      conn.post "claimServicesExternalService/listAllIntentToFile" do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = "{}"
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
