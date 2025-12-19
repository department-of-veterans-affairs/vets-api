# frozen_string_literal: true

require 'central_mail/service'
require 'benefits_intake_service/service'
require 'pdf_utilities/datestamp_pdf'
require 'pdf_info'
require 'simple_forms_api_submission/metadata_validator'

module DependentsBenefits::Sidekiq
  ##
  # Backup submission job that uploads claims to Lighthouse Benefits Intake
  #
  # Used as a fallback when primary BGS submission fails. Submits the entire
  # claim package (main form and attachments) to Lighthouse Benefits Intake API.
  # Unlike primary submissions, does not fail the parent group if this fails,
  # and marks parent as PROCESSING rather than SUCCESS to indicate VBMS pending.
  #
  class DependentBackupJob < DependentSubmissionJob
    # Submit a claim to Lighthouse Benefits Intake as backup
    # @return [ServiceResponse]
    def submit_claims_to_service
      find_or_create_form_submission
      create_form_submission_attempt

      saved_claim.add_veteran_info(user_data)
      raise Invalid686cClaim unless saved_claim.valid?(:run_686_form_jobs)

      submit_to_service
    end

    ##
    # Service-specific submission logic for Lighthouse upload
    # @return [ServiceResponse] Must respond to success? and error methods
    def submit_to_service
      lighthouse_submission = DependentsBenefits::BenefitsIntake::LighthouseSubmission.new(saved_claim, user_data)
      @uuid = lighthouse_submission.initialize_service
      update_submission_attempt_uuid
      lighthouse_submission.prepare_submission
      lighthouse_submission.upload_to_lh
      DependentsBenefits::ServiceResponse.new(status: true)
    rescue => e
      DependentsBenefits::ServiceResponse.new(status: false, error: e)
    ensure
      lighthouse_submission&.cleanup_file_paths
    end

    # Handles job failure by determining if error is permanent or transient
    # @param error [Exception] The error that caused the job to fail
    # @return [void]
    # @raise [::Sidekiq::JobRetry::Skip] for permanent failures to skip retries
    # @raise [DependentSubmissionError] for transient failures to trigger retries
    def handle_job_failure(error)
      monitor.track_submission_error("Error submitting #{self.class}", 'error', error:, claim_id:)
      mark_submission_attempt_failed(error)

      # raise other errors to trigger Sidekiq retry mechanism
      raise DependentSubmissionError, error
    end

    # Handles permanent failure for backup job
    #
    # Simplified failure handling compared to primary jobs - only sends failure
    # notification and logs the error. Does not update parent group status since
    # backup job failures should not prevent subsequent retry attempts.
    #
    # @param claim_id [Integer] ID of the SavedClaim that failed
    # @param error [Exception] The error that caused the permanent failure
    # @return [void]
    def handle_permanent_failure(claim_id, error)
      @claim_id = claim_id
      notification_email.send_error_notification
      monitor.log_silent_failure_avoided({ claim_id:, error: })
    rescue => e
      # Last resort if notification fails
      monitor.log_silent_failure({ claim_id:, error: e })
    end

    # Handles successful backup submission
    #
    # Marks submission as succeeded and updates parent group to PROCESSING status
    # (not SUCCESS) to indicate the claim has been accepted by Lighthouse but hasn't
    # reached VBMS yet. Sends in-progress notification to veteran. Does not check
    # sibling status since backup jobs override previous failures.
    # Atomic updates prevent partial state corruption.
    #
    # @return [void]
    def handle_job_success
      ActiveRecord::Base.transaction do
        parent_group.with_lock do
          mark_submission_attempt_succeeded # update attempt record

          # update parent claim group status - overwrite failure since we're in backup job
          # the parent group is marked as processing to indicate it hasn't reached VBMS yet
          mark_parent_group_processing
        end
      end
    rescue => e
      monitor.track_submission_error('Error handling job success', 'success_failure',
                                     error: e, parent_claim_id: claim_id)
    end

    private

    # Returns the memoized SavedClaim for the current claim ID
    #
    # @return [SavedClaim] The saved claim record
    # @raise [ActiveRecord::RecordNotFound] if claim not found
    def saved_claim = @saved_claim ||= ::SavedClaim.find(claim_id)

    # Returns the Lighthouse Benefits Intake UUID for this submission
    #
    # @return [String, nil] The benefits intake UUID, or nil if not yet initialized
    def uuid = @uuid || nil

    # Finds or creates a Lighthouse form submission record
    #
    # Creates a Lighthouse::Submission record if one doesn't exist for this claim,
    # or returns the existing one. Sets form_id and reference_data on creation.
    #
    # @return [Lighthouse::Submission] The submission record
    def find_or_create_form_submission
      @submission = Lighthouse::Submission.find_or_create_by!(saved_claim_id: saved_claim.id) do |submission|
        submission.assign_attributes({ form_id: saved_claim.form_id, reference_data: saved_claim.to_json })
      end
    end

    # Creates a new Lighthouse form submission attempt record
    #
    # Each retry gets its own attempt record for debugging and tracking.
    #
    # @return [Lighthouse::SubmissionAttempt] The newly created attempt record
    def create_form_submission_attempt
      @submission_attempt = Lighthouse::SubmissionAttempt.create(submission:, benefits_intake_uuid: uuid)
    end

    # Updates the submission attempt with the Lighthouse UUID
    #
    # Called after the Lighthouse service initializes and generates a UUID.
    #
    # @return [Boolean, nil] Result of the update, or nil if attempt doesn't exist
    def update_submission_attempt_uuid
      submission_attempt&.update(benefits_intake_uuid: @uuid)
    end

    # Marks the submission attempt as succeeded
    #
    # Service-specific success logic - updates submission attempt record to success status.
    #
    # @return [Boolean, nil] Result of status update, or nil if attempt doesn't exist
    def mark_submission_attempt_succeeded = submission_attempt&.success!

    # Marks the submission attempt as failed
    #
    # Service-specific failure logic - updates submission attempt record to failed status.
    #
    # @param _exception [Exception] The exception that caused the failure (unused)
    # @return [Boolean, nil] Result of status update, or nil if attempt doesn't exist
    def mark_submission_attempt_failed(_exception) = submission_attempt&.fail!

    # No-op for Lighthouse submissions
    #
    # Lighthouse submission records don't have a failed status, so this is a no-op.
    #
    # @param _exception [Exception] The exception that caused the failure (unused)
    # @return [nil]
    def mark_submission_failed(_exception) = nil

    # Always returns false for backup jobs
    #
    # Backup jobs don't check parent group status - they always attempt submission
    # regardless of previous failures, since they're the fallback mechanism.
    #
    # @return [Boolean] Always false
    def parent_group_failed? = false
  end
end
