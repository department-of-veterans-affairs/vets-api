# frozen_string_literal: true
require 'faraday'
require 'multi_json'
require 'common/client/errors'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/request/multipart_request'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'
require 'sm/middleware/response/sm_parser'
require 'sm/client_session'
require 'sm/configuration'
require 'sm/api/sessions'
require 'sm/api/triage_teams'
require 'sm/api/folders'
require 'sm/api/messages'
require 'sm/api/message_drafts'
require 'sm/api/attachments'

module SM
  class Client
    include SM::API::Sessions
    include SM::API::TriageTeams
    include SM::API::Folders
    include SM::API::Messages
    include SM::API::MessageDrafts
    include SM::API::Attachments

    REQUEST_TYPES = %i(get post delete).freeze
    USER_AGENT = 'Vets.gov Agent'
    BASE_REQUEST_HEADERS = {
      'Accept' => 'application/json',
      'User-Agent' => USER_AGENT
    }.freeze

    attr_reader :config, :session

    def initialize(session:)
      @config = SM::Configuration.instance
      @session = SM::ClientSession.find_or_build(session)
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

      send(method, path, params, headers)
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
        conn.request :camelcase
        conn.request :multipart_request
        conn.request :multipart
        conn.request :json

        conn.response :sm_parser
        conn.response :snakecase
        conn.response :raise_error
        conn.response :json_parser
        # conn.response :logger, ::Logger.new(STDOUT), bodies: true

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
