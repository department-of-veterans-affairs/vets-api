# frozen_string_literal: true

# This initializer has two parts.
# Part 1. Overrides SecureRandom and is necessary in both the development and test environments.
# It does not disable the normal behavior of SecureRandom in any way unless it is invoked.
# Part 2 of this initializer introduces a Rack Middleware that helps record all internal interactions,
# external interactions, and the settings provided to the middleware to faciliate future
# playback in specs.

# Only override SecureRandom in development and test environments.
if Rails.env.development? || Rails.env.test?
  # The module SecureRandom is used in a lot of places. By overriding this one method
  # SecureRandom#random_bytes, it effectively makes randomization of things such as UUID
  # and tokens less random.
  # You'll notice that it uses Time.current with milleseconds removed as the seed
  # This is because VCR records dates in httpdate format (without milleseconds).
  # This allows for specs to play back internal_interactions in recorded cassettes and use
  # the same seed value when generating "unique" ids and other hashes
  require 'securerandom'

  module SecureRandom
    # First we define our new insecure method
    def self.insecure_random_bytes(n = nil)
      n = n ? n.to_int : 16
      Kernel.srand(Time.current.change(usec: 0).to_i)
      Array.new(n) { Kernel.rand(256) }.pack('C*')
    end

    # This is the correct way to invoke enabling and disabling and
    # SecureRandom randomness. By passing a block, this method
    # will yield with insecure random enabled, and disable insecure_random_bytes
    # regardless of whether or not the yielded block raises an exception or not.
    def self.with_disabled_randomness
      enable_insecure
      yield
    ensure
      disable_insecure
    end

    # Swaps the original random_bytes with the insecure version
    # preserves the original in a new alias
    def self.enable_insecure
      class << self
        alias_method :original_random_bytes, :random_bytes
        alias_method :random_bytes, :insecure_random_bytes
      end
    end

    # Swaps the insecure random_bytes method back with the original.
    def self.disable_insecure
      class << self
        alias_method :random_bytes, :original_random_bytes
      end
    end
  end
end

# You must pass in a name for the this middleware to use to record.
if Rails.env.development? && ENV['DUALDECK_INTERACTION']

  # Configure VCR to record specs, filtering out similar fashion to how we do in RSpec
  # NOTE: This could eventually be consolidated in one place.
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
    c.filter_sensitive_data('<EVSS_AWS_BASE_URL>') { Settings.evss.aws.url }
    c.filter_sensitive_data('<LIGHTHOUSE_DIRECT_DEPOSIT_HOST>') { Settings.lighthouse.direct_deposit.host }
    c.filter_sensitive_data('<GIDS_URL>') { Settings.gids.url }
    c.filter_sensitive_data('<MHV_HOST>') { Settings.mhv.rx.host }
    c.filter_sensitive_data('<MHV_SM_APP_TOKEN>') { Settings.mhv.sm.app_token }
    c.filter_sensitive_data('<MHV_SM_HOST>') { Settings.mhv.sm.host }
    c.filter_sensitive_data('<MPI_URL>') { IdentitySettings.mvi.url }
    c.filter_sensitive_data('<PRENEEDS_HOST>') { Settings.preneeds.host }
    c.before_record do |i|
      %i[response request].each do |env|
        next unless i.send(env).headers.keys.include?('Token')

        i.send(env).headers.update('Token' => '<SESSION_TOKEN>')
      end
    end
  end

  # This is the Rack Middleware responsible for recording cassettes
  # It supports freezing current time as well as
  module DualDeck
    class RackMiddleware
      def initialize(app, options = {})
        @app = app
        @replay = options[:replay]
        @feature = options[:feature]
        @insecure_random = options[:insecure_random] || false
        @time_freeze = options[:time_freeze]

        # automatically freezing time when insecure random because it depends on it
        @time_freeze = true if @insecure_random
        record_feature_settings unless File.exist?(feature_path)
      end

      def record_feature_settings
        directory = File.dirname(feature_path)
        FileUtils.mkdir_p(directory)
        File.binwrite(feature_path, { replay_settings: feature_settings }.to_yaml)
      end

      def feature_path
        VCR.configuration.cassette_library_dir + "/#{@feature}/replay_settings.yml"
      end

      def feature_settings
        {
          vcr_cassette_path: relative_cassette_path,
          internal_cassette:,
          external_cassette:,
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

      # This middleware will capture internal requests and external requests.
      def call(env)
        if @feature
          ::VCR.use_cassette(feature_settings[:internal_cassette], record: :new_episodes) do
            middlewares { capture_internal_interaction(env) }
          end
        else
          capture_internal_interaction(env)
        end
      end

      # These mini-middlewares are defined below and enabled with options passed in to
      # DualDeck::RackMiddleware
      def middlewares(&)
        time_freeze_middleware { insecure_middleware(&) }
      end

      # Its unclear if Timecop's block method ensures that Time is returned so
      # we implement our own here. This ensures that regardless of an exception
      # time is unfrozen between interactions. This is necessary to avoid issues
      # with NotBefore, etc
      def freeze_time
        Timecop.freeze(Time.current)
        yield
      ensure
        Timecop.return
      end

      # Only freeze the time if this setting is passed to the middleware
      def time_freeze_middleware(&)
        if @time_freeze
          freeze_time(&)
        else
          yield
        end
      end

      # Only disable randomness if this setting is passed to the middleware
      def insecure_middleware(&)
        if @insecure_random
          SecureRandom.with_disabled_randomness(&)
        else
          yield
        end
      end

      # This method captures internal requests those between vets-website and vets-api
      # It calls capture_external_interactions for capturing external interactions
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

      # This method will capture all external requests made to hosts such as MVI
      def capture_external_interactions
        result = nil
        VCR.use_cassette(feature_settings[:external_cassette], record: :new_episodes) do
          result = yield
        end
        result
      end
    end
  end

  # Enable the RackMiddleware
  # The settings below will ensure that only new interactions are recorded and not replayed back.
  # They will record the feature fixtures in:
  # vcr_cassettes/<ENV['DUALDECK_INTERACTION']>
  # If you need to record interactions again, make sure to delete any existing interactions first
  # You can enable insecure_random, which will automatically also enable time freezing in between each request
  relative_cassette_path = VCR.configuration.cassette_library_dir.split(Dir.pwd.to_s)[1].sub('/', '')
  full_feature_path = relative_cassette_path + "/#{ENV['DUALDECK_INTERACTION']}"
  raise "Interaciton Exists! #{full_feature_path} or provide different interaction" if File.exist?(full_feature_path)

  middleware_options = { replay: false, feature: ENV['DUALDECK_INTERACTION'], insecure_random: true }
  Rails.configuration.middleware.insert(0, DualDeck::RackMiddleware, middleware_options)
end
