# frozen_string_literal: true
require 'faraday'
require 'multi_json'
require 'common/client/errors'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'
require 'rx/api/health_check'
require 'rx/configuration'

module Rx
  # Core class responsible for api interface operations
  class HealthCheckClient
    include Rx::API::HealthChecks

    REQUEST_TYPES = %i(get).freeze
    USER_AGENT = 'Vets.gov Agent'
    BASE_REQUEST_HEADERS = {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'User-Agent' => USER_AGENT
    }.freeze

    attr_reader :config

    def initialize
      @config = Rx::Configuration.instance
    end

    private

    def perform(method, path, params, headers = nil)
      raise NoMethodError, "#{method} not implemented" unless REQUEST_TYPES.include?(method)

      send(method, path, params || {}, headers)
    end

    def request(method, path, params = {}, headers = {})
      connection.send(method.to_sym, path, params) { |request| request.headers.update(headers) }.env
    rescue Faraday::Error::TimeoutError, Timeout::Error => error
      raise Common::Client::Errors::RequestTimeout, error
    rescue Faraday::Error::ClientError => error
      raise Common::Client::Errors::Client, error
    end

    def get(path, params, headers = base_headers)
      request(:get, path, params, headers)
    end

    def connection
      @connection ||= Faraday.new(config.base_path, headers: BASE_REQUEST_HEADERS, request: request_options) do |conn|
        conn.use :breakers
        conn.request :json
        # Uncomment this out for generating curl output to send to MHV dev and test only
        # conn.request :curl, ::Logger.new(STDOUT), :warn

        # conn.response :logger, ::Logger.new(STDOUT), bodies: true
        conn.response :snakecase
        conn.response :raise_error
        conn.response :json_parser

        conn.adapter Faraday.default_adapter
      end
    end

    def auth_headers
      BASE_REQUEST_HEADERS.merge('appToken' => config.app_token)
    end

    def request_options
      {
        open_timeout: config.open_timeout,
        timeout: config.read_timeout
      }
    end
  end
end
