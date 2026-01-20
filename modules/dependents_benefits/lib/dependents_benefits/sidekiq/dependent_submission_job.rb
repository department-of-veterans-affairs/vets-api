# frozen_string_literal: true

require 'sidekiq/job_retry'
require 'dependents_benefits/monitor'

module DependentsBenefits::Sidekiq
  # Custom error class for dependent submission failures
  class DependentSubmissionError < StandardError; end

  ##
  # Abstract base class for coordinated submission of related 686c and 674 claims
  #
  # COORDINATION PATTERN:
  # - Parent claim spawns multiple child claims (686c, 674s) with shared proc_id
  # - Each child gets separate job that checks sibling status before processing
  # - Uses pessimistic locking to prevent race conditions between siblings
  # - Early exits if any sibling has already failed the claim group
  class DependentSubmissionJob
    include ::Sidekiq::Job

    # dead: false ensures critical dependent claims never go to dead queue
    # https://github.com/sidekiq/sidekiq/wiki/Advanced-Options#jobs
    sidekiq_options retry: 16, dead: false

    # Callback runs outside job context - must recreate instance state
    sidekiq_retries_exhausted do |msg, exception|
      monitor = DependentsBenefits::Monitor.new
      claim_id, _proc_id = msg['args']

      # Use the class of the inheriting job that exhausted, not the base class
      job_class_name = msg['class']

      if job_class_name.blank?
        # If we don't have a job class name, the error is irrecoverable
        monitor.log_silent_failure({ claim_id:, error: exception })
      else
        monitor.track_submission_info("Retries exhausted for #{job_class_name} claim_id #{claim_id}", 'exhaustion',
                                      claim_id:)

        job_class = job_class_name.constantize
        job_class.new.send(:handle_permanent_failure, claim_id, exception)
      end
    end

    # Main job execution method for submitting dependent claims
    #
    # Coordinates the submission of a single claim (686c or 674) to the appropriate
    # service. Implements early exit if parent group has already failed. Creates
    # form submission records and handles success/failure outcomes.
    #
    # @param claim_id [Integer] ID of the SavedClaim to submit
    # @param proc_id [String, nil] Optional processing ID for tracking related submissions
    # @return [void]
    # @raise [DependentSubmissionError] if submission fails and should be retried
    def perform(claim_id, proc_id = nil)
      @claim_id = claim_id
      @proc_id = proc_id

      monitor.track_submission_info("Starting #{self.class} for claim_id #{claim_id}", 'start', claim_id:,
                                                                                                parent_claim_id:)

      # Early exit optimization - prevents unnecessary service calls
      return if parent_group_failed?

      @service_response = submit_claims_to_service

      raise DependentSubmissionError, @service_response&.error unless @service_response&.success?

      handle_job_success
    rescue => e
      handle_job_failure(e)
    end

    private

    attr_reader :claim_id, :proc_id

    # Submit claims to the appropriate service
    # @abstract Subclasses must implement this method
    # @return [void]
    def submit_claims_to_service
      raise NotImplementedError, 'Subclasses must implement submit_claims_to_service method'
    end

    # Submit a 686c form to the service
    # @abstract Subclasses must implement this method
    # @param claim [SavedClaim] The 686c claim to submit
    # @return [void]
    def submit_686c_form(claim)
      raise NotImplementedError, 'Subclasses must implement submit_686c_form method'
    end

    # Submit a 674 form to the service
    # @abstract Subclasses must implement this method
    # @param claim [SavedClaim] The 674 claim to submit
    # @return [void]
    def submit_674_form(claim)
      raise NotImplementedError, 'Subclasses must implement submit_674_form method'
    end

    # Check if a submission has already succeeded
    # @abstract Subclasses must implement this method
    # @param submission [FormSubmission] The form submission record to check
    # @return [Boolean] true if submission previously succeeded
    def submission_previously_succeeded?(submission)
      raise NotImplementedError, 'Subclasses must implement submission_previously_succeeded?'
    end

    # Use .find_or_create to generate/return memoized service-specific form submission record
    # @return [LighthouseFormSubmission, BGSFormSubmission] instance
    def find_or_create_form_submission(claim)
      raise NotImplementedError, 'Subclasses must implement find_or_create_form_submission'
    end

    # Generate a new form submission attempt record
    # Each retry gets its own attempt record for debugging
    # @return [LighthouseFormSubmissionAttempt, BGSFormSubmissionAttempt] instance
    def create_form_submission_attempt(submission)
      raise NotImplementedError, 'Subclasses must implement create_form_submission_attempt'
    end

    # Mark a submission attempt as succeeded
    # @abstract Subclasses must implement this method
    # @param submission_attempt [FormSubmissionAttempt] The attempt to mark as succeeded
    # @return [void]
    def mark_submission_attempt_succeeded(submission_attempt)
      raise NotImplementedError, 'Subclasses must implement mark_submission_attempt_succeeded'
    end

    # Service-specific failure logic
    # Update submission attempt record only with failure and error details
    def mark_submission_attempt_failed(submission_attempt, exception)
      raise NotImplementedError, 'Subclasses must implement mark_submission_attempt_failed'
    end

    # Service-specific failure logic for permanent failures
    # Update form submission record to failed
    def mark_submission_failed(exception)
      raise NotImplementedError, 'Subclasses must implement mark_submission_failed'
    end

    # Returns the child claims for this submission
    # @return [Array<SavedClaim>] Array of child claim records
    def child_claims
      @child_claims ||= claim_processor.collect_child_claims
    end

    # Submit a single claim to the service
    # @param claim [SavedClaim] The claim to submit
    # @return [DependentsBenefits::ServiceResponse] Response indicating success or failure
    def submit_claim_to_service(claim)
      submission = find_or_create_form_submission(claim)
      return DependentsBenefits::ServiceResponse.new(status: true) if submission_previously_succeeded?(submission)

      submission_attempt = create_form_submission_attempt(submission)
      claim.add_veteran_info(user_data)
      if claim.form_id == DependentsBenefits::ADD_REMOVE_DEPENDENT
        raise DependentsBenefits::Invalid686cClaim unless claim.valid?(:run_686_form_jobs)

        submit_686c_form(claim)
      elsif claim.form_id == DependentsBenefits::SCHOOL_ATTENDANCE_APPROVAL
        raise DependentsBenefits::Invalid674Claim unless claim.valid?(:run_686_form_jobs)

        submit_674_form(claim)
      end
      mark_submission_attempt_succeeded(submission_attempt)
      DependentsBenefits::ServiceResponse.new(status: true)
    rescue => e
      monitor.track_submission_error("Submission attempt failure in #{self.class}", 'claim.error',
                                     error: e, parent_claim_id:, saved_claim_id: claim.id)
      mark_submission_attempt_failed(submission_attempt, e)
      DependentsBenefits::ServiceResponse.new(status: false, error: e.message)
    end

    # Handles successful job completion with coordinated status updates
    # @return [void]
    def handle_job_success
      monitor.track_submission_info("Successfully submitted #{self.class} for parent_claim_id #{parent_claim_id}",
                                    'success', parent_claim_id:)
      claim_processor.handle_successful_submission
    rescue => e
      monitor.track_submission_error('Error handling job success', 'success_failure', error: e, claim_id:,
                                                                                      parent_claim_id:)
    end

    # Handles job failure by determining if error is permanent or transient
    #
    # Marks the submission attempt as failed. For permanent failures, skips Sidekiq
    # retries and triggers permanent failure handling. For transient failures,
    # raises error to trigger Sidekiq retry mechanism.
    # Distinguishes permanent vs transient failures for retry logic.
    #
    # @param error [Exception] The error that caused the job to fail
    # @return [void]
    # @raise [::Sidekiq::JobRetry::Skip] for permanent failures to skip retries
    # @raise [DependentSubmissionError] for transient failures to trigger retries
    def handle_job_failure(error)
      monitor.track_submission_error("Error submitting #{self.class}", 'error', error:, claim_id:, parent_claim_id:)

      if permanent_failure?(error)
        # Skip Sidekiq retries for permanent failures
        handle_permanent_failure(claim_id, error)
        raise ::Sidekiq::JobRetry::Skip
      end
      # raise other errors to trigger Sidekiq retry mechanism
      raise DependentSubmissionError, error
    end

    # Handles permanent failure by marking records as failed and triggering backup
    #
    # Called from retries_exhausted callback OR permanent failure detection.
    # CRITICAL: Recreates instance state since callback runs outside job context.
    # Uses pessimistic locking to mark submission and claim groups as failed,
    # triggers backup job if parent group not yet completed, and sends error
    # notification as last resort if transaction fails.
    #
    # @param claim_id [Integer] ID of the SavedClaim that failed
    # @param exception [Exception] The error that caused the permanent failure
    # @return [void]
    def handle_permanent_failure(claim_id, exception)
      # Reset claim_id class variable for if this was called from sidekiq_retries_exhausted
      @claim_id = claim_id
      monitor.track_submission_error("Error submitting #{self.class}", 'error.permanent', error: exception, claim_id:,
                                                                                          parent_claim_id:)
      claim_processor.handle_permanent_failure(exception)
    rescue => e
      begin
        notification_email.send_error_notification
        monitor.log_silent_failure_avoided({ claim_id:, error: e })
      rescue => e
        # Last resort notification fails
        monitor.log_silent_failure({ claim_id:, error: e })
      end
    end

    # Checks if the parent claim group has already failed
    #
    # Prevents wasted work when sibling jobs have determined failure.
    # If the parent claim group is already failed, all jobs are considered failed.
    #
    # @return [Boolean] true if parent group has failed status
    def parent_group_failed?
      parent_group&.failed?
    end

    # Determines if an error represents a permanent failure
    #
    # Override in subclasses for service-specific permanent failures
    # (e.g., INVALID_SSN, DUPLICATE_CLAIM, etc). Base implementation assumes
    # all errors are transient.
    #
    # @param error [Exception, nil] The error to check
    # @return [Boolean] true if error is permanent, false if transient
    def permanent_failure?(error)
      return false if error.nil?

      false # Base: assume all errors are transient
    end

    # Marks the parent claim group as succeeded
    #
    # @return [Boolean] result of the update operation
    def mark_parent_group_succeeded
      parent_group&.update!(status: SavedClaimGroup::STATUSES[:SUCCESS])
    end

    # Marks the parent claim group as failed
    #
    # @return [Boolean] result of the update operation
    def mark_parent_group_failed
      parent_group&.update!(status: SavedClaimGroup::STATUSES[:FAILURE])
    end

    # Marks the parent claim group as processing
    #
    # @return [Boolean] result of the update operation
    def mark_parent_group_processing
      parent_group.update!(status: SavedClaimGroup::STATUSES[:PROCESSING])
    end

    # Returns the parent claim group
    #
    # @return [SavedClaimGroup] The parent claim group record
    # @raise [ActiveRecord::RecordNotFound] if parent claim group not found
    def parent_group
      SavedClaimGroup.by_saved_claim_id(parent_claim_id).first!
    end

    # Returns the memoized SavedClaim for the current claim ID
    #
    # @return [SavedClaim] The saved claim record
    # @raise [ActiveRecord::RecordNotFound] if claim not found
    def saved_claim
      @saved_claim ||= ::SavedClaim.find(claim_id)
    end

    # Returns a memoized instance of the DependentsBenefits monitor
    #
    # @return [DependentsBenefits::Monitor] Monitor instance for tracking events and errors
    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end

    # Returns the parent claim ID for the current claim
    #
    # @return [Integer] The parent claim's ID
    def parent_claim_id
      # TODO: Rename claim_id to parent_claim_id throughout for clarity
      @parent_claim_id ||= @claim_id
    end

    # Returns the parsed user data from the parent claim group
    #
    # @return [Hash] Parsed JSON containing veteran information
    def user_data
      @user_data ||= JSON.parse(parent_group.user_data)
    end

    # Returns a notification email handler for the claim
    #
    # @return [DependentsBenefits::NotificationEmail] Notification email instance
    def notification_email
      @notification_email ||= DependentsBenefits::NotificationEmail.new(parent_claim_id, generate_user_struct)
    end

    # Returns the memoized form submission record
    #
    # @return [LighthouseFormSubmission, BGSFormSubmission] The submission record
    def submission
      @submission ||= find_or_create_form_submission
    end

    # Returns the memoized form submission attempt record
    #
    # @return [LighthouseFormSubmissionAttempt, BGSFormSubmissionAttempt] The attempt record
    def submission_attempt
      @submission_attempt ||= create_form_submission_attempt
    end

    # Generates an OpenStruct representing a user from stored user data
    #
    # Creates a user-like object from the veteran information stored in the
    # parent claim group's user_data JSON. Used for passing to service clients
    # that expect a user object interface.
    #
    # @return [OpenStruct] User-like object with veteran information attributes
    def generate_user_struct
      info = user_data['veteran_information']
      full_name = info['full_name']
      OpenStruct.new(
        first_name: full_name['first'],
        last_name: full_name['last'],
        middle_name: full_name['middle'],
        ssn: info['ssn'],
        email: info['email'],
        va_profile_email: info['va_profile_email'],
        participant_id: info['participant_id'],
        icn: info['icn'],
        uuid: info['uuid'],
        common_name: info['common_name']
      )
    end

    # Returns a memoized instance of the claim processor
    # @return [DependentsBenefits::ClaimProcessor] Processor for handling claim operations
    def claim_processor
      @claim_processor ||= DependentsBenefits::ClaimProcessor.new(parent_claim_id)
    end
  end
end
