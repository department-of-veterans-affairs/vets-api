# frozen_string_literal: true
module Common
  module Client
    # Configuration class used to setup the environment used by client
    class Configuration
      # Timeouts are in seconds
      # http://docs.ruby-lang.org/en/2.0.0/Net/HTTP.html#attribute-i-open_timeout
      # http://docs.ruby-lang.org/en/2.0.0/Net/HTTP.html#attribute-i-read_timeout
      OPEN_TIMEOUT = 15
      READ_TIMEOUT = 15

      attr_reader :app_token, :open_timeout, :read_timeout

      def initialize(host:, app_token:, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, enforce_ssl: true)
        @app_token = app_token
        @host = URI.parse(host)
        @open_timeout = open_timeout
        @read_timeout = read_timeout
        assert_ssl if enforce_ssl
      end

      def base_path
        raise NotImplementedError, 'you must provide a base_path.'
      end

      private

      def assert_ssl
        raise ArgumentError, 'host must use ssl' unless @host.is_a?(URI::HTTPS)
      end
    end
  end
end
