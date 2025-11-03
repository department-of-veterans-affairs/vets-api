# frozen_string_literal: true

require 'mpi/responses/profile_parser'
require 'mpi/errors/errors'

module MPI
  module Services
    class FindProfileResponseCreator
      attr_reader :type, :response, :error

      def initialize(type:, response: nil, error: nil)
        @type = type
        @response = response
        @error = error
      end

      def perform
        validations
        if error_status
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
          Rails.logger.warn("[MPI][Services][FindProfileResponseCreator] MPI #{type} response error",
                            error_message: detailed_error&.message)
        elsif profile_parser.invalid_request? || profile_parser.no_match? || profile_parser.unknown_error?
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
            Errors::DuplicateRecords.new(error_details)
          elsif profile_parser.failed_request?
            Errors::FailedRequestError.new(error_details)
          elsif profile_parser.invalid_request? || profile_parser.unknown_error?
            Errors::RecordNotFound.new(error_details)
          end
      end

      def error_status
        @error_status ||=
          if error.present? || profile_parser.failed_request?
            :server_error
          elsif profile_parser.multiple_match? ||
                profile_parser.invalid_request? ||
                profile_parser.no_match? ||
                profile_parser.unknown_error?
            :not_found
          end
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
