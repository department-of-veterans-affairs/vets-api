# frozen_string_literal: true

require 'debt_management_center/base_service'

module DebtsApi
  module V0
    class DigitalDisputeSubmissionService < DebtManagementCenter::BaseService
      MAX_FILE_SIZE = 1.megabyte
      ACCEPTED_CONTENT_TYPE = 'application/pdf'

      class InvalidFileTypeError < StandardError; end
      class FileTooLargeError < StandardError; end
      class NoFilesProvidedError < StandardError; end

      def initialize(user, files)
        super(user)
        @files = files
      end

      def call
        validate_files_present
        validate_files

        send_to_dmc
        in_progress_form&.destroy
        {
          success: true,
          message: 'Digital dispute submission received successfully'
        }
      rescue => e
        failure_result(e)
      end

      private

      attr_reader :files

      def send_to_dmc
        measure_latency("#{DebtsApi::V0::DigitalDispute::STATS_KEY}.vba.latency") do
          perform(:post, 'dispute-debt', build_payload)
        end
      end

      def build_payload
        {
          file_number: @file_number,
          dispute_pdfs: files.map do |file|
            {
              file_name: sanitize_filename(file.original_filename),
              file_contents: Base64.strict_encode64(file.read)
            }
          end
        }
      end

      def in_progress_form
        InProgressForm.form_for_user('DISPUTE-DEBT', @user)
      end

      def validate_files_present
        if files.blank? || !files.is_a?(Array) || files.empty?
          raise NoFilesProvidedError,
                'at least one file is required'
        end
      end

      def validate_files
        errors = []

        files.each_with_index do |file, index|
          file_index = index + 1

          errors << "File #{file_index} must be a PDF" unless file.content_type == ACCEPTED_CONTENT_TYPE

          errors << "File #{file_index} is too large (maximum is 1MB)" if file.size > MAX_FILE_SIZE
        end

        raise InvalidFileTypeError, errors.join(', ') if errors.any?
      end

      def sanitize_filename(filename)
        name = File.basename(filename)
        name = name.tr(':', '_')
        name.gsub(/[.](?=.*[.])/, '')
      end

      def failure_result(error)
        Rails.logger.error("DigitalDisputeSubmissionService error: #{error.message}")
        case error
        when NoFilesProvidedError
          {
            success: false,
            errors: { files: [error.message] }
          }
        when InvalidFileTypeError
          {
            success: false,
            errors: { files: error.message.split(', ') }
          }
        else
          {
            success: false,
            errors: { base: ['An error occurred processing your submission'] }
          }
        end
      end
    end
  end
end
