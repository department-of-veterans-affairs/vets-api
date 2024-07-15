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
    CODE_BTSSS_TIMEOUT = 'CLM_011_CLAIM_TIMEOUT_ERROR'
    CODE_UNKNOWN_ERROR = 'CLM_030_UNKNOWN_SERVER_ERROR'

    # claim status responses
    CODE_EMPTY_STATUS = 'CLM_020_EMPTY_STATUS'
    CODE_MULTIPLE_STATUSES = 'CLM_021_MULTIPLE_STATUSES'
    CODE_CLAIM_APPROVED = 'CLM_023_CLAIM_APPROVED'
    CODE_CLAIM_NOT_APPROVED = 'CLM_024_CLAIM_NOT_APPROVED'

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
      when 400, 401, 404, 408
        { data: error_data(message: response_body[:message]), status: }
      else
        { data: unknown_error_data, status: }
      end
    end

    def handle_claim_status_response
      response_body = begin
        Oj.load(body)
      rescue
        body
      end
      case status
      when 200
        { data: claim_status_success_data(response_body:), status: }
      when 408
        { data: { error: true, code: CODE_BTSSS_TIMEOUT, message: 'BTSSS timeout error' }, status: }
      else
        { data: { error: true, code: CODE_UNKNOWN_ERROR, message: 'Internal server error' }, status: }
      end
    end

    private

    def claim_status_success_data(response_body:)
      code = if response_body.size.zero?
               CODE_EMPTY_STATUS
             elsif response_body.size > 1
               CODE_MULTIPLE_STATUSES
             else
               CODE_SUCCESS
             end
      { code:, body: response_body }
    end

    def unknown_error_data
      { error: true, code: CODE_UNKNOWN_ERROR, message: 'Internal server error' }
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
                   when /timeout/i
                     CODE_BTSSS_TIMEOUT
                   else
                     CODE_SUBMISSION_ERROR
                   end

      { error: true, code: error_code, message: }
    end
  end
end
