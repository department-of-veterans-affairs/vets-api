# more gem like approach

module Complex
  class Client
    BASE_URL = 'https://api.cars.example.com'

    attr_reader :token, :headers

    def initialize
      api_key = Settings.api_wrapper[:api_key]
      @token = exchange_api_key_for_token(api_key)
      @headers = {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@token}"
      }
      @connection = Faraday.new(url: BASE_URL) do |faraday|
        faraday.headers = @headers
        faraday.request :url_encoded
        faraday.response :logger
        faraday.adapter Faraday.default_adapter
      end
    end

    def request(method:, path:, params: {})
      response = @connection.send(method, path) do |req|
        req.body = params.to_json if params.any?
      end
      parse_response(response)
    end

    def parse_response(response)
      if response.success?
        JSON.parse(response.body)
      else
        handle_error(response)
      end
    end

    def handle_error(response)
      raise "HTTP request failed with status #{response.status}: #{response.body}"
    end

    private

    # Exchange the API key for a Bearer token
    def exchange_api_key_for_token(api_key)
      response = Faraday.post("#{BASE_URL}/auth") do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = { api_key: api_key }.to_json
      end

      parse_response(response)['token']
    end
  end
end
