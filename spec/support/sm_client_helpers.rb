# frozen_string_literal: true
module SM
  module ClientHelpers
    HOST = ENV['MHV_SM_HOST']
    APP_TOKEN = 'fake-app-token'
    TOKEN = 'GkuX2OZ4dCE=48xrH6ObGXZ45ZAg70LBahi7CjswZe8SZGKMUVFIU88='

    SAMPLE_SESSION_REQUEST = {
      headers: {
        'Accept' => 'application/json',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Apptoken' => APP_TOKEN,
        'Content-Type' => 'application/json',
        'Mhvcorrelationid' => '10616687',
        'User-Agent' => 'Vets.gov Agent'
      }
    }.freeze

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

    def authenticated_client
      configuration = SM::Configuration.new(host: HOST,
                                            app_token: APP_TOKEN)
      SM::Client.new(config: configuration,
                     session: { user_id: 123,
                                expires_at: Time.current + 60 * 60,
                                token: TOKEN })
    end
  end
end
