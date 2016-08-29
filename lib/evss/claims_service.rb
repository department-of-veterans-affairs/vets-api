module EVSS
  class Service
    def initialize
      @default_timeout = 5 # seconds
    end

    protected

    def get(url)
      conn.get url
    end

    def post(url, body)
      conn.post url do |req|
        req.headers["Content-Type"] = "application/json"
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

  class ClaimsService < Service
    def initialize(vaafi_headers = {})
      super()
      # TODO: Get base URI from env
      @base_url = "http://csraciapp6.evss.srarad.com:7003/wss-claims-services-web-3.1/rest"
      @headers = vaafi_headers
    end

    def claims
      get "vbaClaimStatusService/getOpenClaims"
    end

    def create_intent_to_file
      post "claimServicesExternalService/listAllIntentToFile", "{}"
    end
  end

  class DocumentsService < Service
    def initialize(vaafi_headers = {})
      super()
      # TODO: Get base URI from env
      @base_url = "http://csraciapp6.evss.srarad.com:7003/wss-document-services-web-3.1/rest/"
      @headers = vaafi_headers
    end

    def all_documents
      get "documents/getAllDocuments"
    end
  end
end
