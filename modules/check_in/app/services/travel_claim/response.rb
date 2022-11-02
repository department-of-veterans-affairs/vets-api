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
        Oj.load(body)
      rescue
        body
      end

      case status
      when 200
        { data: response_body, status: status }
      when 400, 401
        { data: { error: true, message: response_body[:message] }, status: status }
      else
        { data: { error: true, message: 'Claim submission failed' }, status: status }
      end
    end
  end
end
