# frozen_string_literal: true

module Eps
  ##
  # Error class for DraftAppointmentService errors
  #
  # This class standardizes error handling across multiple upstream services (VAOS, EPS, Redis)
  # that each have their own error formats. It provides consistent status code mapping and
  # error information, particularly converting all 5xx errors to :bad_gateway for consistent
  # error responses.
  #
  class DraftAppointmentServiceError < StandardError
    attr_reader :status, :detail

    ##
    # Initialize a new DraftAppointmentServiceError
    #
    # @param message [String] Error message
    # @param status [Symbol, Integer, nil] HTTP status code for the error response
    #        (note: all 5xx status codes are automatically converted to :bad_gateway)
    # @param detail [String, nil] Detailed error information
    #
    def initialize(message, status: nil, detail: nil)
      # Convert any numeric 5xx status to :bad_gateway
      status = :bad_gateway if status.is_a?(Integer) && status >= 500

      @status = status || extract_status(detail)
      @detail = detail
      super(message)
    end

    ##
    # Extracts a status code from an error message if possible
    #
    # Handles VAOS error code patterns like 'code: "VAOS_404"' and similar formats.
    # All 5xx status codes found in the error message are converted to :bad_gateway.
    #
    # @param error_message [String, nil] Error message that might contain a status code
    # @return [Symbol, Integer] Extracted status code; returns :bad_gateway if
    #         a 5xx code was found or if no valid code could be extracted
    #
    def extract_status(error_message)
      return :bad_gateway unless error_message.is_a?(String)

      if (match = error_message.match(/(?:code:|:code\s*=>)\s*["']VAOS_(\d{3})["']/i))
        status_code = match[1].to_i
        return :bad_gateway if status_code >= 500

        return status_code
      end

      :bad_gateway
    end
  end
end
