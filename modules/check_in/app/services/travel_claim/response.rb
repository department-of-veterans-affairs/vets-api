# frozen_string_literal: true

module TravelClaim
  class Response
    attr_reader :body, :status

    CODE_SUCCESS = 'CLM_000_SUCCESS'
    CODE_MULTIPLE_APPTS = 'CLM_001_MULTIPLE_APPTS'
    CODE_CLAIM_EXISTS = 'CLM_002_CLAIM_EXISTS'
    CODE_APPT_NOT_FOUND = 'CLM_003_APPOINTMENT_NOT_FOUND'
    CODE_INVALID_AUTH = 'CLM_020_INVALID_AUTH'
    CODE_SUBMISSION_ERROR = 'CLM_010_CLAIM_SUBMISSION_ERROR'

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
        { data: response_body.merge(code: CODE_SUCCESS), status: }
      when 400, 401, 404
        { data: error_data(message: response_body[:message]), status: }
      else
        { data: unknown_error_data, status: }
      end
    end

    private

    def unknown_error_data
      { error: true, code: 'CLM_030_UNKNOWN_SERVER_ERROR', message: 'Internal server error' }
    end

    def error_data(message:)
      error_code = case message
                   when /multiple appointments/i
                     CODE_MULTIPLE_APPTS
                   when /already has a claim/i
                     CODE_CLAIM_EXISTS
                   when /appointment not found/i
                     CODE_APPT_NOT_FOUND
                   when /unauthorized/i
                     CODE_INVALID_AUTH
                   else
                     CODE_SUBMISSION_ERROR
                   end

      { error: true, code: error_code, message: }
    end
  end
end
