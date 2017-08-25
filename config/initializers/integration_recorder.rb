if Rails.env.development? || Rails.env.test?
  require "securerandom"

  module SecureRandom
    def self.insecure_random_bytes(n = nil)
      n = n ? n.to_int : 16
      Kernel.srand(Time.now.to_i)
      Array.new(n) { Kernel.rand(256) }.pack("C*")
    end

    def self.enable_insecure
      class << self
        alias_method :original_random_bytes, :random_bytes
        alias_method :random_bytes, :insecure_random_bytes
      end
    end

    def self.disable_insecure
      class << self
        alias_method :random_bytes, :original_random_bytes
      end
    end
  end
end

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
        SecureRandom.enable_insecure
        result = run_inbound_request(env)
        SecureRandom.disable_insecure
        result
      end
    end

    def run_inbound_request(env)
      req = Rack::Request.new(env)
      transaction = Rack::VCR::Transaction.new(req)

      if Settings.integration_recorder.replay && transaction.can_replay?
        transaction.replay
      else
        Timecop.freeze(Time.now.change(usec: 0))
        status, headers, body = run_outbound_request { @app.call(env) }
        Timecop.return
        res = Rack::Response.new(body, status, headers)
        transaction.capture(res)
        [status, headers, body]
      end
    end

    def run_outbound_request
      cassette = Settings.integration_recorder.outbound_cassette_dir
      VCR.use_cassette(cassette, record: :new_episodes) do
        yield
      end
    end
  end
  Rails.configuration.middleware.insert(0, InboundCassetteRecorder)
end
