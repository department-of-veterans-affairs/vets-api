# frozen_string_literal: true

module V2
  module Lorota
    class Client
      extend Forwardable

      attr_reader :claims_token, :check_in, :settings

      def_delegators :settings, :url, :base_path, :api_id, :api_key, :service_name

      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @settings = Settings.check_in.lorota_v2
        @check_in = opts[:check_in]
        @claims_token = ClaimsToken.build(check_in: check_in).sign_assertion
      end

      def token
        connection.post("/#{base_path}/token") do |req|
          req.headers = default_headers.merge('x-lorota-claims' => claims_token)
          req.body = auth_params.to_json
        end
      end

      def data(token:)
        connection.get("/#{base_path}/data/#{check_in.uuid}") do |req|
          req.headers = default_headers.merge('Authorization' => "Bearer #{token}")
        end
      end

      private

      def connection
        Faraday.new(url: url) do |conn|
          conn.use :breakers
          conn.response :raise_error, error_prefix: service_name
          conn.response :betamocks if Settings.check_in.lorota_v2.mock

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

      def auth_params
        {
          SSN4: check_in.last4,
          lastName: check_in.last_name
        }
      end
    end
  end
end
