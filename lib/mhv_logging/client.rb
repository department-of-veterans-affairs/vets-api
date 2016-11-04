# frozen_string_literal: true
require 'faraday'
require 'common/client/errors'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'
require 'mhv_logging/api/audits'
require 'rx/api/sessions'
require 'rx/configuration'
require 'rx/client_session'

# NOTE: This client uses the exact same configuration, breakers, and client session
# as Rx does. It is the same server, but we're building it as a separate client
# for better separation of concerns since it can be invoked when using secure messaging

module MHVLogging
  # Core class responsible for api interface operations
  class Client
    include MHVLogging::API::Audits
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

    # Note this uses the same session store as Rx
    def authenticate
      if @session.expired?
        @session = get_session
        @session.save
      end
      self
    end

    private

    def perform(method, path, params, headers = nil)
      raise NoMethodError, "#{method} not implemented" unless REQUEST_TYPES.include?(method)

      send(method, path, params || {}, headers)
    end

    def request(method, path, params = {}, headers = {})
      raise_not_authenticated if headers.keys.include?('Token') && headers['Token'].nil?
      connection.send(method.to_sym, path, params) { |request| request.headers.update(headers) }.env
    rescue Faraday::Error::TimeoutError, Timeout::Error => error
      raise Common::Client::Errors::RequestTimeout, error
    rescue Faraday::Error::ClientError => error
      raise Common::Client::Errors::Client, error
    end

    def get(path, params, headers = base_headers)
      request(:get, path, params, headers)
    end

    def post(path, params, headers = base_headers)
      request(:post, path, params, headers)
    end

    def raise_not_authenticated
      raise Common::Client::Errors::NotAuthenticated, 'Not Authenticated'
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
