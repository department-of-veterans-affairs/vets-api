# frozen_string_literal: true
require 'faraday'
require 'multi_json'
require 'common/client/errors'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'
require 'rx/middleware/response/rx_parser'
require 'rx/configuration'
require 'rx/client_session'

module Rx
  # Core class responsible for api interface operations
  class Client
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
      self
    end

    def get_active_rxs
      json = perform(:get, 'prescription/getactiverx', nil, token_headers).body
      Common::Collection.new(::Prescription, json)
    end

    def get_history_rxs
      json = perform(:get, 'prescription/gethistoryrx', nil, token_headers).body
      Common::Collection.new(::Prescription, json)
    end

    def get_rx(id)
      collection = get_history_rxs
      collection.find_first_by('prescription_id' => { 'eq' => id })
    end

    def get_tracking_rx(id)
      json = perform(:get, "prescription/rxtracking/#{id}", nil, token_headers).body
      data = json[:data].first.merge(prescription_id: id)
      Tracking.new(json.merge(data: data))
    end

    def get_tracking_history_rx(id)
      json = perform(:get, "prescription/rxtracking/#{id}", nil, token_headers).body
      tracking_history = json[:data].map { |t| Hash[t].merge(prescription_id: id) }
      Common::Collection.new(::Tracking, json.merge(data: tracking_history))
    end

    def post_refill_rx(id)
      perform(:post, "prescription/rxrefill/#{id}", nil, token_headers)
    end

    def get_session
      env = perform(:get, 'session', nil, auth_headers)
      req_headers = env.request_headers
      res_headers = env.response_headers
      Rx::ClientSession.new(user_id: req_headers['mhvCorrelationId'],
                            expires_at: res_headers['expires'],
                            token: res_headers['token'])
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
        conn.response :rx_parser
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
