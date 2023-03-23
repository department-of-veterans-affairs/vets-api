# frozen_string_literal: true

module TravelClaim
  class Response
    attr_reader :body, :status

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
        { data: response_body, status: }
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
                     'CLM_001_MULTIPLE_APPTS'
                   when /already has a claim/i
                     'CLM_002_CLAIM_EXISTS'
                   when /appointment not found/i
                     'CLM_003_APPOINTMENT_NOT_FOUND'
                   when /unauthorized/i
                     'CLM_020_INVALID_AUTH'
                   else
                     'CLM_010_CLAIM_SUBMISSION_ERROR'
                   end

      { error: true, code: error_code, message: }
    end
  end
end
