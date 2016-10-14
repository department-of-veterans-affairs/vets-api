# frozen_string_literal: true
module Rx
  module ClientHelpers
    HOST = ENV['MHV_HOST']
    APP_TOKEN = 'your-unique-app-token'
    TOKEN = 'GkuX2OZ4dCE=48xrH6ObGXZ45ZAg70LBahi7CjswZe8SZGKMUVFIU88='

    SAMPLE_SESSION_RESPONSE = {
      status: 200,
      body: '',
      headers: {
        'date' => 'Tue, 10 May 2016 16:30:17 GMT',
        'server' => 'Apache/2.2.15 (Red Hat)',
        'content-length' => '0',
        'expires' => 'Tue, 10 May 2016 16:40:17 GMT',
        'token' => TOKEN,
        'x-powered-by' => 'Servlet/2.5 JSP/2.1',
        'connection' => 'close',
        'content-type' => 'text/plain; charset=UTF-8',
        'cache-control' => 'no-cache',
        'access-control-allow-origin' => '*'
      }
    }.freeze

    def setup_client
      stub_request(:get, "#{HOST}/mhv-api/patient/v1/session")
        .to_return(SAMPLE_SESSION_RESPONSE)

      Rx::Client.new(session: { user_id: 123 })
    end

    def authenticated_client
      Rx::Client.new(session: { user_id: 123,
                                expires_at: Time.current + 60 * 60,
                                token: TOKEN })
    end

    def stub_varx_request(method, api_endpoint, response_hash, opts = {})
      with_opts = { headers: Rx::Client::BASE_REQUEST_HEADERS.merge('Token' => TOKEN) }
      with_opts[:body] = opts[:body] unless opts[:body].nil?
      status_code = opts[:status_code] || 200

      response = response_hash.nil? ? '' : response_hash

      stub_request(method, "#{HOST}/#{api_endpoint}")
        .with(with_opts)
        .to_return(status: status_code, body: response)
    end
  end
end
