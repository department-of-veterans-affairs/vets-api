if Rails.env.development? && Settings.integration_recorder.enabled == true
  ENV['ENABLE_VCR_CABLE'] = 'true'
  VCR.configure do |c|
    c.hook_into 'webmock'
    c.default_cassette_options = {
       :erb => false,
       :allow_playback_repeats => false
    }
    c.cassette_library_dir = Settings.integration_recorder.base_cassette_dir
    c.allow_http_connections_when_no_cassette = false
  end

  class InboundCassetteRecorder
    def initialize(app, options = {})
      @app = app
    end

    def call(env)
      VCR.use_cassette(Settings.integration_recorder.inbound_cassette_dir, record: :new_episodes) do
        run_request(env)
      end
    end

    def run_request(env)
      req = Rack::Request.new(env)
      transaction = Rack::VCR::Transaction.new(req)

      if Settings.integration_recorder.replay && transaction.can_replay?
        transaction.replay
      else
        status, headers, body = @app.call(env)
        res = Rack::Response.new(body, status, headers)
        transaction.capture(res)
        [status, headers, body]
      end
    end
  end

  Rails.configuration.middleware.insert(0, InboundCassetteRecorder)
end
