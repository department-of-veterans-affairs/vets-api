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

module SM
  class Client
    CONTENT_DISPOSITION = 'attachment; filename='
    MHV_MAXIMUM_PER_PAGE = 250
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
      self
    end

    def get_session
      env = perform(:get, 'session', nil, auth_headers)
      req_headers = env.request_headers
      res_headers = env.response_headers
      SM::ClientSession.new(user_id: req_headers['mhvCorrelationId'],
                            expires_at: res_headers['expires'],
                            token: res_headers['token'])
    end

    def get_triage_teams
      json = perform(:get, 'triageteam', nil, token_headers).body
      Common::Collection.new(TriageTeam, json)
    end

    def get_folders
      json = perform(:get, 'folder', nil, token_headers).body
      Common::Collection.new(Folder, json)
    end

    def get_folder(id)
      json = perform(:get, "folder/#{id}", nil, token_headers).body
      Folder.new(json)
    end

    def post_create_folder(name)
      json = perform(:post, 'folder', { 'name' => name }, token_headers).body
      Folder.new(json)
    end

    def delete_folder(id)
      response = perform(:delete, "folder/#{id}", nil, token_headers)
      response.nil? ? nil : response.status
    end

    def get_folder_messages(folder_id)
      page = 1
      json = { data: [], errors: {}, metadata: {} }

      loop do
        path = "folder/#{folder_id}/message/page/#{page}/pageSize/#{MHV_MAXIMUM_PER_PAGE}"
        page_data = perform(:get, path, nil, token_headers).body
        json[:data].concat(page_data[:data])
        json[:metadata].merge(page_data[:metadata])
        break unless page_data[:data].size == MHV_MAXIMUM_PER_PAGE
        page += 1
      end

      Common::Collection.new(Message, json)
    end

    def post_create_message_draft(args = {})
      # Prevent call if this is a reply draft, otherwise reply-to message suject can change.
      validate_draft(args)

      json = perform(:post, 'message/draft', args, token_headers).body
      MessageDraft.new(json)
    end

    def post_create_message_draft_reply(id, args = {})
      # prevent call if this an existing draft with no association to a reply-to message
      validate_reply_draft(args)

      json = perform(:post, "message/#{id}/replydraft", args, token_headers).body
      json[:data][:has_message] = true

      MessageDraft.new(json).as_reply
    end

    def reply_draft?(id)
      get_message_history(id).data.present?
    end

    def validate_draft(args)
      draft = MessageDraft.new(args)
      draft.as_reply if args[:id] && reply_draft?(args[:id])

      raise Common::Exceptions::ValidationErrors, draft unless draft.valid?
    end

    def validate_reply_draft(args)
      draft = MessageDraft.new(args).as_reply
      draft.has_message = !args[:id] || reply_draft?(args[:id])

      raise Common::Exceptions::ValidationErrors, draft unless draft.valid?
    end

    def get_categories
      path = 'message/category'

      json = perform(:get, path, nil, token_headers).body
      Category.new(json)
    end

    def get_message(id)
      path = "message/#{id}/read"
      json = perform(:get, path, nil, token_headers).body

      Message.new(json)
    end

    def get_message_history(id)
      path = "message/#{id}/history"
      json = perform(:get, path, nil, token_headers).body

      Common::Collection.new(Message, json)
    end

    def post_create_message(args = {})
      validate_create_context(args)

      json = perform(:post, 'message', args, token_headers).body
      Message.new(json)
    end

    def post_create_message_with_attachment(args = {})
      validate_create_context(args)

      json = perform(:post, 'message/attach', args, token_headers).body
      Message.new(json)
    end

    def post_create_message_reply_with_attachment(id, args = {})
      validate_reply_context(args)

      json = perform(:post, "message/#{id}/reply/attach", args, token_headers).body
      Message.new(json)
    end

    def post_create_message_reply(id, args = {})
      validate_reply_context(args)

      json = perform(:post, "message/#{id}/reply", args, token_headers).body
      Message.new(json)
    end

    def post_move_message(id, folder_id)
      custom_headers = token_headers.merge('Content-Type' => 'application/json')
      response = perform(:post, "message/#{id}/move/tofolder/#{folder_id}", nil, custom_headers)

      response.nil? ? nil : response.status
    end

    def delete_message(id)
      custom_headers = token_headers.merge('Content-Type' => 'application/json')
      response = perform(:post, "message/#{id}", nil, custom_headers)

      response.nil? ? nil : response.status
    end

    def get_attachment(message_id, attachment_id)
      path = "message/#{message_id}/attachment/#{attachment_id}"

      response = perform(:get, path, nil, token_headers)
      filename = response.response_headers['content-disposition'].gsub(CONTENT_DISPOSITION, '')
      { body: response.body, filename: filename }
    end

    def validate_create_context(args)
      if args[:id].present? && reply_draft?(args[:id])
        draft = MessageDraft.new(args.merge(has_message: true)).as_reply
        draft.errors.add(:base, 'attempted to use reply draft in send message')

        raise Common::Exceptions::ValidationErrors, draft
      end
    end

    def validate_reply_context(args)
      if args[:id].present? && !reply_draft?(args[:id])
        draft = MessageDraft.new(args)
        draft.errors.add(:base, 'attempted to use plain draft in send reply')

        raise Common::Exceptions::ValidationErrors, draft
      end
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

    def delete(path, params, headers = base_headers)
      request(:delete, path, params, headers)
    end

    def raise_not_authenticated
      raise Common::Client::Errors::NotAuthenticated, 'Not Authenticated'
    end

    def connection
      @connection ||= Faraday.new(@config.base_path, headers: BASE_REQUEST_HEADERS, request: request_options) do |conn|
        conn.use :breakers
        conn.request :camelcase
        conn.request :multipart_request
        conn.request :multipart
        conn.request :json
        # Uncomment this out for generating curl output to send to MHV dev and test only
        # conn.request :curl, ::Logger.new(STDOUT), :warn

        # conn.response :logger, ::Logger.new(STDOUT), bodies: true
        conn.response :sm_parser
        conn.response :snakecase
        conn.response :raise_error
        conn.response :json_parser

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
