# frozen_string_literal: true

module DebtsApi
  module V0
    class DigitalDisputeSubmissionService
      MAX_FILE_SIZE = 1.megabyte
      ACCEPTED_CONTENT_TYPE = 'application/pdf'

      class InvalidFileTypeError < StandardError; end
      class FileTooLargeError < StandardError; end
      class NoFilesProvidedError < StandardError; end

      def initialize(files)
        @files = files
      end

      def call
        validate_files_present
        validate_files

        process_files

        {
          success: true,
          message: 'Digital dispute submission received successfully'
        }
      rescue => e
        failure_result(e)
      end

      private

      attr_reader :files

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

      def process_files
        files.each do |file|
          sanitize_filename(file.original_filename)
        end
      end

      def sanitize_filename(filename)
        name = File.basename(filename)
        name = name.tr(':', '_')
        name.gsub(/[.](?=.*[.])/, '')
      end

      def failure_result(error)
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
