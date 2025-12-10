# frozen_string_literal: true

require 'debt_management_center/base_service'
require 'debts_api/v0/digital_dispute_submission'
require 'sidekiq/attr_package'

module DebtsApi
  module V0
    class DigitalDisputeSubmissionService < DebtManagementCenter::BaseService
      MAX_FILE_SIZE = 1.megabyte
      ACCEPTED_CONTENT_TYPE = 'application/pdf'

      configuration DebtManagementCenter::DebtsConfiguration

      SUBMISSION_TEMPLATE = Settings.vanotify.services.dmc.template_id.digital_dispute_submission_email
      CONFIRMATION_TEMPLATE = Settings.vanotify.services.dmc.template_id.digital_dispute_confirmation_email
      FAILURE_TEMPLATE = Settings.vanotify.services.dmc.template_id.digital_dispute_failure_email

      def initialize(user, files, metadata = nil)
        super(user)
        @files = files
        @metadata = metadata
      end

      def call
        submission = create_submission_record
        transaction_log = DebtTransactionLog.track_dispute(submission, @user)
        return duplicate_submission_result(submission) if check_duplicate?(submission)

        send_to_dmc
        transaction_log&.mark_submitted
        send_submission_email if email_notifications_enabled?
        submission.register_success
        transaction_log&.mark_completed
        in_progress_form&.destroy

        success_result(submission)
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("DigitalDisputeSubmissionService ActiveRecord error: #{e.message}")
        failure_result(e)
      rescue => e
        submission&.register_failure(e.message)
        transaction_log&.mark_failed
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
            file.tempfile.rewind
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
          disputes = @metadata[:disputes] || []

          submission.store_debt_identifiers(disputes)

          # Store non-PII data in public_metadata
          submission.store_public_metadata
        end

        submission.files.attach(files) if files.present?

        raise ActiveRecord::RecordInvalid, submission unless submission.valid?

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
          .exists?(['debt_identifiers @> ?', submission.debt_identifiers.to_json])
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
          submission_id: submission.guid,
          message: 'Digital dispute submission received successfully'
        }
      end

      def failure_result(error)
        base_hash = { success: false }

        details = case error
                  when ActiveRecord::RecordInvalid
                    { error_type: 'validation_error', errors: { base: error.record.errors.full_messages } }
                  else
                    {
                      error_type: 'processing_error', errors: { base: ['An error occurred processing your submission'] }
                    }
                  end

        base_hash.merge!(details)
      end

      def email_notifications_enabled?
        Flipper.enabled?(:digital_dispute_email_notifications) && @user.email.present?
      end

      def send_submission_email
        cache_key = Sidekiq::AttrPackage.create(email: @user.email, first_name: @user.first_name)
        DebtsApi::V0::Form5655::SendConfirmationEmailJob.perform_in(
          5.minutes,
          {
            'submission_type' => 'digital_dispute',
            'cache_key' => cache_key,
            'user_uuid' => @user.uuid,
            'template_id' => DigitalDisputeSubmission::SUBMISSION_TEMPLATE
          }
        )
      end
    end
  end
end
