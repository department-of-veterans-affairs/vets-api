# frozen_string_literal: true
if Rails.env.development? || Rails.env.test?
  require 'securerandom'

  module SecureRandom
    def self.insecure_random_bytes(n = nil)
      n = n ? n.to_int : 16
      Kernel.srand(Time.now.change(usec: 0).to_i)
      Array.new(n) { Kernel.rand(256) }.pack('C*')
    end

    def self.with_disabled_randomness
      self.enable_insecure
      yield
    ensure
      self.disable_insecure
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
    c.hook_into :webmock
    c.default_cassette_options = {
      erb: false,
      allow_playback_repeats: false
    }
    c.cassette_library_dir = Settings.integration_recorder.base_cassette_dir
    c.allow_http_connections_when_no_cassette = false
    c.filter_sensitive_data('<APP_TOKEN>') { Settings.mhv.rx.app_token }
    c.filter_sensitive_data('<EVSS_BASE_URL>') { Settings.evss.url }
    c.filter_sensitive_data('<GIDS_URL>') { Settings.gids.url }
    c.filter_sensitive_data('<MHV_HOST>') { Settings.mhv.rx.host }
    c.filter_sensitive_data('<MHV_SM_APP_TOKEN>') { Settings.mhv.sm.app_token }
    c.filter_sensitive_data('<MHV_SM_HOST>') { Settings.mhv.sm.host }
    c.filter_sensitive_data('<MVI_URL>') { Settings.mvi.url }
    c.filter_sensitive_data('<PRENEEDS_HOST>') { Settings.preneeds.host }
    c.before_record do |i|
      %i(response request).each do |env|
        next unless i.send(env).headers.keys.include?('Token')
        i.send(env).headers.update('Token' => '<SESSION_TOKEN>')
      end
    end
  end

  module DualDeck
    class RackMiddleware
      def initialize(app, options = {})
        @app = app
        @replay = options[:replay]
        @feature = options[:feature]
        @insecure_random = options[:insecure_random] || false
        @time_freeze = options[:time_freeze]

        if @insecure_random
          @time_freeze = true
        end
        record_feature_settings unless File.exist?(feature_path)
      end

      def record_feature_settings
        directory = File.dirname(feature_path)
        FileUtils.mkdir_p(directory) unless File.exist?(directory)
        File.binwrite(feature_path, { replay_settings: feature_settings }.to_yaml )
      end

      def feature_path
        VCR.configuration.cassette_library_dir + "/#{@feature}/replay_settings.yml"
      end

      def feature_settings
        {
          vcr_cassette_path: relative_cassette_path,
          internal_cassette: internal_cassette,
          external_cassette: external_cassette,
          insecure_random: @insecure_random,
          time_freeze: @time_freeze
        }
      end

      def relative_cassette_path
        VCR.configuration.cassette_library_dir.split(Dir.pwd.to_s)[1].sub('/', '')
      end

      def internal_cassette
        "#{@feature}/internal_interactions"
      end

      def external_cassette
        "#{@feature}/external_interactions"
      end

      def call(env)
        if @feature
          ::VCR.use_cassette(feature_settings[:internal_cassette], record: :new_episodes) do
            middlewares { capture_internal_interaction(env) }
          end
        else
          capture_internal_interaction(env)
        end
      end

      def middlewares
        time_freeze_middleware { insecure_middleware { yield } }
      end

      def freeze_time
        result = nil
        Timecop.freeze(Time.now)
        result = yield
      ensure
        Timecop.return
      end

      def time_freeze_middleware
        if @time_freeze
          freeze_time { yield }
        else
          yield
        end
      end

      def insecure_middleware
        if @insecure_random
          SecureRandom.with_disabled_randomness { yield }
        else
          yield
        end
      end

      def capture_internal_interaction(env)
        req = Rack::Request.new(env)
        transaction = Rack::VCR::Transaction.new(req)

        if @replay && transaction.can_replay?
          transaction.replay
        else
          status, headers, body = capture_external_interactions { @app.call(env) }
          res = Rack::Response.new(body, status, headers)
          transaction.capture(res)
          [status, headers, body]
        end
      end

      def capture_external_interactions
        result = nil
        VCR.use_cassette(feature_settings[:external_cassette], record: :new_episodes) do
          result = yield
        end
        result
      end
    end
  end

  middleware_options = { replay: false, feature: 'complex_interaction', insecure_random: true }
  Rails.configuration.middleware.insert(0, DualDeck::RackMiddleware, middleware_options)
end
