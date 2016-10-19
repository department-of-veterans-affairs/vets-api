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

    attr_reader :config, :session

    def initialize(session:)
      @config = Rx::Configuration.instance
      @session = Rx::ClientSession.find_or_build(session)
    end

    def authenticate
      if @session.expired?
        @session = get_session
        @session.save
      end
      @session
    end

    private

    def perform(method, path, params = nil, headers = nil)
      raise NoMethodError, "#{method} not implemented" unless REQUEST_TYPES.include?(method)
      @response = send(method, path, params, headers)
      process_response_or_error
    end

    def process_response_or_error
      process_no_content_response || process_other
    end

    def process_no_content_response
      # MHV is providing a normal string for successful POST, not JSON
      return unless @response.body.empty? || @response.body.start_with?('Successfully submitted to:')
      @response if @response.success?
    end

    def process_other
      json = begin
        MultiJson.load(@response.body)
      rescue MultiJson::LoadError => error
        # we should log the response body, but i'm reluctant to do it in case it
        # makes it into production and includes private information.
        raise Common::Client::Errors::Serialization, error
      end
      return Rx::Parser.new(json).parse! if @response.success?
      raise Common::Client::Errors::ClientResponse.new(@response.status, json)
    end

    def request(method, path, params = {}, headers = {})
      raise_not_authenticated if headers.keys.include?('Token') && headers['Token'].nil?
      connection.send(method.to_sym, path, params) do |request|
        request.headers.update(headers)
      end.env
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
      @connection ||= Faraday.new(config.base_path, headers: BASE_REQUEST_HEADERS, request: request_options) do |conn|
        conn.use :breakers
        conn.adapter :httpclient
      end
    end

    def auth_headers
      BASE_REQUEST_HEADERS.merge('appToken' => config.app_token, 'mhvCorrelationId' => @session.user_id.to_s)
    end

    def token_headers
      BASE_REQUEST_HEADERS.merge('Token' => @session.token)
    end

    def request_options
      {
        open_timeout: config.open_timeout,
        timeout: config.read_timeout
      }
    end
  end
end
