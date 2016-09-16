# frozen_string_literal: true
require 'faraday'
require 'multi_json'
require 'common/client/errors'
require 'va_healthcare_messaging/client_session'
require 'va_healthcare_messaging/configuration'
# require 'va_healthcare_messaging/parser'
require 'va_healthcare_messaging/api/sessions'

module VaHealthcareMessaging
  #####################################################################################################################
  ## Client
  ## Core class responsible for api interface operations with MHV.
  #####################################################################################################################
  class Client
    include VaHealthcareMessaging::API::Sessions
    # include VaHealthcareMessaging::API::TriageTeams
    # include VaHealthcareMessaging::API::Folders
    # include VaHealthcareMessaging::API::Messages

    REQUEST_TYPES = %i(get post delete).freeze
    USER_AGENT = 'Vets.gov Agent'
    BASE_REQUEST_HEADERS = {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'User-Agent' => USER_AGENT
    }.freeze

    attr_reader :config, :session

    ###################################################################################################################
    ## initialize
    ## Intializes the client with both configuration and a session. The configuration contians both the host URL and
    ## the app_token used to validate the app. The session contains at a minimum the correlation id for the user (if
    ## no session has yet been established, or has expired).
    ###################################################################################################################
    def initialize(config:, session:)
      @config = config.is_a?(Hash) ? VaHealthcareMessaging::Configuration.new(config) : config
      @session = session.is_a?(Hash) ? VaHealthcareMessaging::ClientSession.new(session) : session

      raise ArgumentError, 'config is invalid' unless @config.is_a?(Configuration)
      raise ArgumentError, 'session is invalid' unless @session.valid?
    end

    ###################################################################################################################
    ## authenticate
    ## Gets a valid session token from MHV.
    ###################################################################################################################
    def authenticate
      @session = get_session
    end

    private

    ###################################################################################################################
    ## perform
    ## Communicates with an MHV endpoint.
    ##
    ## method:  HTTP method (get, post, ...)
    ## path:    The MHV endpoint path (session, folders, etc) appended to the MHV URL.
    ## params:  HTTP variable-value pairs as a hash
    ## headers: HTTP headers.
    ##
    ## Action is
    ## response = (get, post, ...) -> request -> connection.(get, post, ...) { }.env
    ###################################################################################################################
    def perform(method, path, params = nil, headers = nil)
      raise NoMethodError, "#{method} not implemented" unless REQUEST_TYPES.include?(method)

      @response = send(method, path, params, headers)
      process_response_or_error
    end

    ###################################################################################################################
    ## process_response_or_error
    ## Processes the response from the perform method. If the response was successful with no body, the response
    ## headers are returned directly. Otherwise the body of the response is converted to a ruby hash and then parsed
    ## as JSON if the body represents a sucessful response.
    ###################################################################################################################
    def process_response_or_error
      if @response.body.empty? || @response.body.casecmp('success').zero?
        return @response if @response.status == 200
      end

      json = begin
        MultiJson.load(@response.body)
      rescue MultiJson::LoadError => error
        raise Common::Client::Errors::Serialization, error
      end

      return VaHealthcareMessaging::Parser.new(json).parse! if @response.status == 200
      raise Common::Client::Errors::ClientResponse.new(@response.status, json)
    end

    ###################################################################################################################
    ## request
    ## Sends a request and receives a response from MHV. Requires a valid token before doing so.
    ###################################################################################################################
    def request(method, path, params = {}, headers = {})
      raise_not_authenticated if headers.keys.include?('Token') && headers['Token'].nil?
      connection.send(method.to_sym, path, params) { |request| request.headers.update(headers) }.env
    rescue Faraday::Error::TimeoutError, Timeout::Error => error
      raise Common::Client::Errors::RequestTimeout, error
    rescue Faraday::Error::ClientError => error
      raise Common::Client::Errors::Client, error
    end

    ###################################################################################################################
    ## get
    ## Forwards a get request.
    ###################################################################################################################
    def get(path, params = {}, headers = base_headers)
      request(:get, path, params, headers)
    end

    ###################################################################################################################
    ## post
    ## Forwards a post request.
    ###################################################################################################################
    def post(path, params = {}, headers = base_headers)
      request(:post, path, params, headers)
    end

    ###################################################################################################################
    ## delete
    ## Forwards a delete request.
    ###################################################################################################################
    def delete(path, _params = {}, headers = base_headers)
      request(:delete, path, nil, headers)
    end

    ###################################################################################################################
    ## raise_not_authenticated
    ###################################################################################################################
    def raise_not_authenticated
      raise Common::Client::Errors::NotAuthenticated, 'Not Authenticated'
    end

    ###################################################################################################################
    ## connection
    ## Memoize a faraday instance passing basic timeout options and accept/content-type/user-agent headers.
    ##
    ## Faraday requires Rackmiddleware to be specified from outside wrapper to in.
    ##   multipart: checks for files in the payload, otherwise leaves everything untouched.
    ##   url_encoded: encodes as "application/x-www-form-urlencoded" if not already encoded or of another type.
    ##   adapter: the http adapter used to communicate via http.
    ###################################################################################################################
    def connection
      @connection ||= Faraday.new(@config.base_path, headers: BASE_REQUEST_HEADERS, request: request_options) do |conn|
        conn.request :multipart
        conn.request :url_encoded

        conn.adapter Faraday.default_adapter
      end
    end

    ###################################################################################################################
    ## auth_headers
    ## MHV required data to authorized both this app and its user, merged with the basic headers for an MHV request.
    ###################################################################################################################
    def auth_headers
      BASE_REQUEST_HEADERS.merge('appToken' => @config.app_token, 'mhvCorrelationId' => @session.user_id.to_s)
    end

    ###################################################################################################################
    ## token_headers
    ## MHV required current session token, merged with the basic headers for an MHV request.
    ###################################################################################################################
    def token_headers
      BASE_REQUEST_HEADERS.merge('Token' => @session.token)
    end

    ###################################################################################################################
    ## request_options
    ## Used by Faraday, and instructs both open timeout and single-read timeout in seconds.
    ###################################################################################################################
    def request_options
      {
        open_timeout: @config.open_timeout,
        timeout: @config.read_timeout
      }
    end
  end
end
