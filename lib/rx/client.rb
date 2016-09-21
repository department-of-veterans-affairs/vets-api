# frozen_string_literal: true
require 'faraday'
require 'multi_json'
require 'common/client/errors'
require 'rx/configuration'
require 'rx/client_session'
require 'rx/parser'
require 'rx/api/prescriptions'
require 'rx/api/sessions'

module Rx
  # Core class responsible for api interface operations
  class Client
    include Rx::API::Prescriptions
    include Rx::API::Sessions

    REQUEST_TYPES = %i(get post).freeze
    USER_AGENT = 'Vets.gov Agent'
    BASE_REQUEST_HEADERS = {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'User-Agent' => USER_AGENT
    }.freeze

    MHV_CONFIG = Rx::Configuration.new(
      host: ENV['MHV_HOST'],
      app_token: ENV['MHV_APP_TOKEN'],
      enforce_ssl: Rails.env.production?
    ).freeze

    attr_reader :config, :session

    def initialize(config: MHV_CONFIG, session:)
      @config = config.is_a?(Hash) ? Rx::Configuration.new(config) : config
      @session = session.is_a?(Hash) ? Rx::ClientSession.new(session) : session
      raise ArgumentError, 'config is invalid' unless @config.is_a?(Configuration)
      raise ArgumentError, 'session is invalid' unless @session.valid?
    end

    def authenticate
      @session = get_session
    end

    private

    def perform(method, path, params = nil, headers = nil)
      raise NoMethodError, "#{method} not implemented" unless REQUEST_TYPES.include?(method)
      @response = send(method, path, params, headers)
      process_response_or_error
    end

    def process_response_or_error
      return @response if @response.status == 200 && @response.body.empty?
      json = begin
        MultiJson.load(@response.body)
      rescue MultiJson::LoadError => error
        raise Common::Client::Errors::Serialization, error
      end
      return Rx::Parser.new(json).parse! if @response.status == 200
      raise Common::Client::Errors::ClientResponse.new(@response.status, json)
    end

    def request(method, path, params = {}, headers = {})
      raise_not_authenticated if headers.keys.include?('Token') && headers['Token'].nil?
      connection.send(method.to_sym, path, params) { |request| request.headers.update(headers) }.env
    rescue Faraday::Error::TimeoutError, Timeout::Error => error
      raise Common::Client::Errors::RequestTimeout, error
    rescue Faraday::Error::ClientError => error
      raise Common::Client::Errors::Client, error
    end

    def get(path, params = {}, headers = base_headers)
      request(:get, path, params, headers)
    end

    def post(path, params = {}, headers = base_headers)
      request(:post, path, params.to_json, headers)
    end

    def raise_not_authenticated
      raise Common::Client::Errors::NotAuthenticated, 'Not Authenticated'
    end

    def connection
      @connection ||= Faraday.new(@config.base_path, headers: BASE_REQUEST_HEADERS, request: request_options)
    end

    def auth_headers
      BASE_REQUEST_HEADERS.merge('appToken' => @config.app_token, 'mhvCorrelationId' => @session.user_id.to_s)
    end

    def token_headers
      BASE_REQUEST_HEADERS.merge('Token' => @session.token)
    end

    def request_options
      {
        open_timeout: @config.open_timeout,
        timeout: @config.read_timeout
      }
    end
  end
end
