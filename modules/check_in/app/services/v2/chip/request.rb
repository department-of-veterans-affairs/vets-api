# frozen_string_literal: true

module V2
  module Chip
    class Request
      extend Forwardable
      include Common::Client::Concerns::Monitoring

      STATSD_KEY_PREFIX = 'api.check_in.v2.chip_api.request'

      attr_reader :settings

      def_delegators :settings, :service_name, :tmp_api_id, :url

      def self.build
        new
      end

      def initialize
        @settings = Settings.check_in.chip_api_v2
      end

      def get(opts = {})
        with_monitoring do
          connection.get(opts[:path]) do |req|
            req.headers = headers.merge('Authorization' => "Bearer #{opts[:access_token]}")
          end
        end
      end

      def post(opts = {})
        with_monitoring do
          connection.post(opts[:path]) do |req|
            prefix = opts[:access_token] ? 'Bearer' : 'Basic'
            suffix = opts[:access_token] || opts[:claims_token]
            req.headers = headers.merge('Authorization' => "#{prefix} #{suffix}")
            req.body = opts[:params].to_json if opts[:access_token]
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

      def headers
        { 'x-apigw-api-id' => tmp_api_id }
      end
    end
  end
end
