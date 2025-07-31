# frozen_string_literal: true

require 'debt_management_center/base_service'
require_relative '../../../app/models/debts_api/v0/digital_dispute_submission'

module DebtsApi
  module V0
    class DigitalDisputeSubmissionService < DebtManagementCenter::BaseService
      MAX_FILE_SIZE = 1.megabyte
      ACCEPTED_CONTENT_TYPE = 'application/pdf'

      class InvalidFileTypeError < StandardError; end
      class FileTooLargeError < StandardError; end
      class NoFilesProvidedError < StandardError; end

      configuration DebtManagementCenter::DebtsConfiguration

      def initialize(user, files, metadata = nil)
        super(user)
        @files = files
        @metadata = metadata
      end

      def call
        validate_files_present
        validate_files

        submission = create_submission_record
        return duplicate_submission_result(submission) if check_duplicate?(submission)

        send_to_dmc
        submission.register_success
        in_progress_form&.destroy

        success_result(submission)
      rescue => e
        submission&.register_failure(e.message)
        failure_result(e)
      end

      private

      attr_reader :files, :metadata

      def send_to_dmc
        measure_latency("#{DebtsApi::V0::DigitalDispute::STATS_KEY}.vba.latency") do
          perform(:post, 'dispute-debt', build_payload)
        end
      end

      def build_payload
        {
          fileNumber: @file_number,
          disputePDFs: files.map do |file|
            {
              fileName: sanitize_filename(file.original_filename),
              fileContents: Base64.strict_encode64(file.read)
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

      def create_submission_record
        submission = DebtsApi::V0::DigitalDisputeSubmission.new(
          user_uuid: @user.uuid,
          user_account: @user.user_account,
          state: :pending
        )

        if @metadata
          # Store encrypted metadata (serialize hash to JSON for lockbox)
          submission.metadata = @metadata.to_json

          # Extract and store debt identifiers for duplicate checking
          disputes = @metadata[:disputes] || @metadata['disputes'] || []
          submission.store_debt_identifiers(disputes)

          # Store non-PII data in public_metadata
          submission.store_public_metadata
        end

        submission.save!
        submission
      end

      def duplicate_submission_exists?(submission)
        return false unless Flipper.enabled?(:digital_dispute_duplicate_prevention)
        return false if submission.debt_identifiers.blank?

        # Check for existing submissions with matching debt identifiers
        DebtsApi::V0::DigitalDisputeSubmission
          .where(user_uuid: @user.uuid)
          .where.not(id: submission.id)
          .where.not(state: :failed)
          .where('debt_identifiers @> ?', submission.debt_identifiers.to_json)
          .exists?
      end


      def check_duplicate?(submission)
        @metadata && duplicate_submission_exists?(submission)
      end

      def duplicate_submission_result(submission)
        submission.register_failure('Duplicate dispute submission')
        {
          success: false,
          error_type: 'duplicate_dispute',
          errors: { base: ['A dispute for these debts has already been submitted'] }
        }
      end

      def success_result(submission)
        {
          success: true,
          submission_id: submission.id,
          message: 'Digital dispute submission received successfully'
        }
      end

      def failure_result(error)
        case error
        when NoFilesProvidedError
          {
            success: false,
            error_type: 'no_files',
            errors: { files: [error.message] }
          }
        when InvalidFileTypeError
          {
            success: false,
            error_type: 'invalid_file',
            errors: { files: error.message.split(', ') }
          }
        else
          {
            success: false,
            error_type: 'processing_error',
            errors: { base: ['An error occurred processing your submission'] }
          }
        end
      end
    end
  end
end
