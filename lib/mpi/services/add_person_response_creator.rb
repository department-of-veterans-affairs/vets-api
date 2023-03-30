# frozen_string_literal: true

require 'mpi/responses/add_parser'
require 'sentry_logging'

module MPI
  module Services
    class AddPersonResponseCreator
      include SentryLogging

      attr_reader :type, :response, :error

      def initialize(type:, response: nil, error: nil)
        @type = type
        @response = response
        @error = error
      end

      def perform
        validations
        if failed_response?
          create_error_response
        else
          create_successful_response
        end
      end

      private

      def validations
        raise Errors::InvalidResponseParamsError unless response.present? ^ error.present?
      end

      def create_successful_response
        Rails.logger.info("[MPI][Services][AddPersonResponseCreator] #{type}, " \
                          "icn=#{parsed_codes[:icn]}, " \
                          "idme_uuid=#{parsed_codes[:idme_uuid]}, " \
                          "logingov_uuid=#{parsed_codes[:logingov_uuid]}, " \
                          "transaction_id=#{parsed_codes[:transaction_id]}")
        Responses::AddPersonResponse.new(status: :ok, parsed_codes:)
      end

      def create_error_response
        log_message_to_sentry("MPI #{type} response error", :warn, { error_message: detailed_error&.message })
        Responses::AddPersonResponse.new(status: :server_error, error: detailed_error)
      end

      def detailed_error
        @detailed_error ||=
          if error
            error
          elsif add_parser.invalid_request?
            Errors::InvalidRequestError.new(error_details)
          elsif add_parser.failed_request?
            Errors::FailedRequestError.new(error_details)
          end
      end

      def failed_response?
        error.present? || add_parser.failed_or_invalid?
      end

      def error_details
        @error_details ||= add_parser.error_details(parsed_codes)
      end

      def parsed_codes
        @parsed_codes ||= add_parser.parse
      end

      def add_parser
        @add_parser ||= Responses::AddParser.new(response)
      end
    end
  end
end
