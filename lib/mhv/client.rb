# frozen_string_literal: true
require 'faraday'
require 'multi_json'
require 'common/client/errors'
require 'mhv/configuration'
require 'mhv/api/new_users'

module MHV
  # Core class responsible for api interface operations
  class Client
    HOST = 'https://www.myhealth.va.gov'
    REQUEST_TYPES = %i(post).freeze
    USER_AGENT = 'Vets.gov Agent'
    BASE_REQUEST_HEADERS = {
      'Accept' => 'text/html',
      'Content-Type' => 'application/x-www-form-urlencoded',
      'User-Agent' => USER_AGENT
    }.freeze

    attr_reader :config

    def initialize
      @config = MHV::Configuration.new(host: HOST)
      raise ArgumentError, 'config is invalid' unless @config.is_a?(Configuration)
    end

    private

    def perform(method, path, params = nil, headers = nil)
      raise NoMethodError, "#{method} not implemented" unless REQUEST_TYPES.include?(method)
      @response = send(method, path, params, headers)
      process_response_or_error
    end

    def process_response_or_error
      puts @response.body
    end

    def request(method, path, params = {}, headers = {})
      connection.send(method.to_sym, path, params) { |request| request.headers.update(headers) }.env
    rescue Faraday::Error::TimeoutError, Timeout::Error => error
      raise Common::Client::Errors::RequestTimeout, error
    rescue Faraday::Error::ClientError => error
      raise Common::Client::Errors::Client, error
    end

    def post(path, params = {}, headers = base_headers)
      request(:post, path, params.to_json, headers)
    end

    def connection
      @connection ||= Faraday.new(@config.base_path, headers: BASE_REQUEST_HEADERS, request: request_options)
    end

    def request_options
      {
        open_timeout: @config.open_timeout,
        timeout: @config.read_timeout
      }
    end
  end
end
