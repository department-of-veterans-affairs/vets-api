# frozen_string_literal: true

module Map
  class Response
    attr_reader :body, :status

    CODE_SUCCESS = 'GET_APPTS_SUCCESS'
    CODE_INVALID_AUTH = 'GET_APPTS_INVALID_AUTH'
    CODE_BAD_REQUEST = 'GET_APPTS_BAD_REQUEST'
    CODE_UNKNOWN_ERROR = 'GET_APPTS_UNKNOWN_ERROR'

    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts)
      @body = opts[:response].body || []
      @status = opts[:response].status
    end

    def handle
      response_body = begin
        Oj.load(body).with_indifferent_access
      rescue
        body
      end

      case status
      when 200
        { data: response_body.merge(code: CODE_SUCCESS), status: :ok }
      when 400, 401, 404
        { data: error_data(opts[:message], opts[:status]), status: :bad_request }
      else
        { data: unknown_error_data, status: :internal_server_error }
      end
    end

    private

    def unknown_error_data
      { error: true, code: 'GET_APPTS_UNKNOWN_SERVER_ERROR', message: 'Internal server error' }
    end

    def error_data(message, custom_status)
      error_code = case message
                   when /bad request/i
                     CODE_BAD_REQUEST
                   when /unauthorized/i
                     CODE_INVALID_AUTH
                   else
                     CODE_UNKNOWN_ERROR
                   end

      { error: true, code: error_code, message:, status: custom_status }
    end
  end
end
