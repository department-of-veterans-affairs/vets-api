# frozen_string_literal: true
require 'faraday'
require 'multi_json'
require 'common/client/errors'
require 'sm/client_session'
require 'sm/configuration'
require 'sm/parser'
require 'sm/api/sessions'
require 'sm/api/triage_teams'
require 'sm/api/folders'
require 'sm/api/messages'

module SM
  class Client
    include SM::API::Sessions
    include SM::API::TriageTeams
    include SM::API::Folders
    include SM::API::Messages

    REQUEST_TYPES = %i(get post delete).freeze
    USER_AGENT = 'Vets.gov Agent'
    BASE_REQUEST_HEADERS = {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'User-Agent' => USER_AGENT
    }.freeze

    MHV_CONFIG = SM::Configuration.new(
      host: ENV['MHV_SM_HOST'],
      app_token: ENV['MHV_SM_APP_TOKEN'],
      enforce_ssl: Rails.env.production?
    ).freeze

    attr_reader :config, :session

    def initialize(config: MHV_CONFIG, session:)
      @config = config.is_a?(Hash) ? SM::Configuration.new(config) : config
      @session = session.is_a?(Hash) ? SM::ClientSession.new(session) : session

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
      if @response.body.empty? || @response.body.casecmp('success').zero?
        return @response if @response.status == 200
      end

      json = begin
        MultiJson.load(@response.body)
      rescue MultiJson::LoadError => error
        raise Common::Client::Errors::Serialization, error
      end

      return SM::Parser.new(json).parse! if @response.status == 200
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
      request(:post, path, params, headers)
    end

    def delete(path, _params = {}, headers = base_headers)
      request(:delete, path, nil, headers)
    end

    def raise_not_authenticated
      raise Common::Client::Errors::NotAuthenticated, 'Not Authenticated'
    end

    def connection
      @connection ||= Faraday.new(@config.base_path, headers: BASE_REQUEST_HEADERS, request: request_options) do |conn|
        conn.request :multipart
        conn.request :url_encoded

        conn.adapter Faraday.default_adapter
      end
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
