# frozen_string_literal: true

module V2
  module Lorota
    class Request
      extend Forwardable
      include Common::Client::Concerns::Monitoring

      STATSD_KEY_PREFIX = 'api.check_in.v2.lorota_api.request'

      attr_reader :claims_token, :settings, :token
      attr_accessor :headers

      def_delegators :settings, :api_key, :api_id, :service_name, :url

      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @settings = Settings.check_in.lorota_v2
        @claims_token = opts[:claims_token]
        @token = opts[:token]
        @headers = default_headers
      end

      def get(path)
        with_monitoring do
          connection.get(path) do |req|
            req.headers = default_headers.merge('Authorization' => "Bearer #{token}")
          end
        end
      end

      def post(path, params)
        with_monitoring do
          connection.post(path) do |req|
            req.headers = default_headers.merge('x-lorota-claims' => claims_token)
            req.body = params.to_json
          end
        end
      end

      def connection
        Faraday.new(url: url) do |conn|
          conn.use :breakers
          conn.response :raise_error, error_prefix: service_name
          conn.adapter Faraday.default_adapter
        end
      end

      def default_headers
        {
          'Content-Type' => 'application/json',
          'x-api-key' => api_key,
          'x-apigw-api-id' => api_id
        }
      end
    end
  end
end
