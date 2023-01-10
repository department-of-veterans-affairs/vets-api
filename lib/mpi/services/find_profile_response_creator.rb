# frozen_string_literal: true

require 'mpi/responses/profile_parser'
require 'sentry_logging'

module MPI
  module Services
    class FindProfileResponseCreator
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
        info_log("icn=#{parsed_profile.icn}, transaction_id=#{parsed_profile.transaction_id}")
        Responses::FindProfileResponse.new(status: :ok, profile: parsed_profile)
      end

      def create_error_response
        log_error_response
        Responses::FindProfileResponse.new(status: error_status, error: detailed_error)
      end

      def log_error_response
        if error || profile_parser.multiple_match? || profile_parser.failed_request?
          log_message_to_sentry("MPI #{type} response error", :warn, { error_message: detailed_error&.message })
        elsif profile_parser.invalid_request? || profile_parser.unknown_error?
          info_log("Record Not Found, transaction_id=#{parsed_profile.transaction_id}")
        end
      end

      def info_log(message)
        Rails.logger.info("[MPI][Services][FindProfileResponseCreator] #{type} #{message}")
      end

      def detailed_error
        @detailed_error ||=
          if error
            error
          elsif profile_parser.multiple_match?
            MPI::Errors::DuplicateRecords.new(error_details)
          elsif profile_parser.failed_request?
            MPI::Errors::FailedRequestError.new(error_details)
          elsif profile_parser.invalid_request? || profile_parser.unknown_error?
            MPI::Errors::RecordNotFound.new(error_details)
          end
      end

      def error_status
        @error_status ||=
          if error || profile_parser.failed_request?
            :server_error
          elsif profile_parser.multiple_match? || profile_parser.invalid_request? || profile_parser.unknown_error?
            :not_found
          end
      end

      def failed_response?
        error.present? ||
          profile_parser.multiple_match? ||
          profile_parser.failed_or_invalid? ||
          profile_parser.unknown_error?
      end

      def error_details
        @error_details ||= profile_parser.error_details
      end

      def parsed_profile
        @parsed_profile ||= profile_parser.parse
      end

      def profile_parser
        @profile_parser ||= Responses::ProfileParser.new(response)
      end
    end
  end
end
