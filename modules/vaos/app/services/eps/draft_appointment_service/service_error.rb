# frozen_string_literal: true

module Eps
  class DraftAppointmentService
    ##
    # Error class for DraftAppointmentService errors
    #
    class ServiceError < StandardError
      attr_reader :status, :error_type, :detail

      ##
      # Initialize a new ServiceError
      #
      # @param message [String] Error message
      # @param status [Symbol, Integer, nil] HTTP status code for the error response
      # @param detail [String, nil] Detailed error information
      # @param error_type [String, nil] Custom error type identifier
      #
      def initialize(message, status: nil, detail: nil)
        @status = status || extract_status(detail)
        @detail = detail
        super(message)
      end

      ##
      # Extracts a status code from an error message if possible
      #
      # @param error_message [String, nil] Error message that might contain a status code
      # @return [Symbol, Integer] Extracted status code, converts 500 to :bad_gateway,
      # or default :bad_gateway if no code found
      #
      def extract_status(error_message)
        return :bad_gateway unless error_message.is_a?(String)

        if (match = error_message.match(/(?:code:|:code\s*=>)\s*["']VAOS_(\d{3})["']/i))
          status_code = match[1].to_i
          return status_code == 500 ? :bad_gateway : status_code
        end

        :bad_gateway
      end

      ##
      # Formats the error into a standard API response
      #
      # @return [Hash] Hash containing error details and HTTP status
      #
      def to_response
        {
          json: {
            errors: [{
              title: message,
              detail: @detail,
              code: 'Eps::DraftAppointmentService::ServiceError'
            }]
          },
          status: @status
        }
      end
    end
  end
end
