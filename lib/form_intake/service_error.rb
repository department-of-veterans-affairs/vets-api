# frozen_string_literal: true

module FormIntake
  # Custom error for GCIO API failures
  class ServiceError < StandardError
    attr_reader :status_code

    def initialize(message, status_code = 500)
      super(message)
      @status_code = status_code
    end

    # Check if error is retryable
    def retryable?
      [408, 429, 500, 502, 503, 504].include?(status_code)
    end
  end
end
