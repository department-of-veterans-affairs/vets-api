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
require 'sm/api/message_drafts'
require 'sm/api/attachments'
require 'faraday_curl'

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

      @response = send(method, path, params, headers)
      process_response_or_error
    end

    def process_response_or_error
      process_no_content_response || process_attachment || process_other
    end

    def process_no_content_response
      return unless @response.body.empty? || @response.body.casecmp('success').zero?
      @response if @response.status == 200
    end

    def process_attachment
      return unless @response.response_headers['content-type'] == 'application/octet-stream'
      disposition = @response.response_headers['content-disposition']
      filename = disposition.gsub('attachment; filename=', '')
      { body: @response.body, filename: filename }
    end

    def process_other
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
      params = params.is_a?(Hash) ? normalize_and_jsonify(params) : params
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
        conn.use :breakers
        conn.request :multipart
        conn.request :json
        # conn.request :curl, ::Logger.new(STDOUT), :warn

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

    def normalize_and_jsonify(params)
      uploads = params.delete(:uploads)
      params = params.transform_keys { |k| k.to_s.camelize(:lower) }

      if uploads.present?
        message_part = Faraday::UploadIO.new(
          StringIO.new(params.to_json),
          'application/json',
          'message'
        )
        file_parts = uploads.map.with_index do |file, _i|
          upload = Faraday::UploadIO.new(
            file.tempfile,
            file.content_type,
            file.original_filename
          )
          [file.original_filename, upload]
        end
        { 'message' => message_part }.merge(Hash[file_parts])
      else
        params
      end
    end
  end
end
