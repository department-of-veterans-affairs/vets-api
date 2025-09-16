# frozen_string_literal: true

module DependentsBenefits
  ##
  # Abstract base class for coordinated submission of related 686c and 674 claims
  #
  # COORDINATION PATTERN:
  # - Parent claim spawns multiple child claims (686c, 674s) with shared proc_id
  # - Each child gets separate job that checks sibling status before processing
  # - Uses pessimistic locking to prevent race conditions between siblings
  # - Early exits if any sibling has already failed the claim group
  #
  # SUBCLASS REQUIREMENTS:
  # - MUST implement submit_to_service for BGS/Lighthouse/Fax submission
  # - MAY override find_or_create_form_submission for service-specific FormSubmission types
  # - MAY override permanent_failure? for service-specific error classification
  #
  class DependentSubmissionJob
    include Sidekiq::Job

    # dead: false ensures critical dependent claims never go to dead queue
    sidekiq_options retry: 16, dead: false

    # Callback runs outside job context - must recreate instance state
    sidekiq_retries_exhausted do |msg, exception|
      claim_id, proc_id = msg['args']
      new.send(:handle_permanent_failure, claim_id, proc_id, exception)
    end

    def perform(claim_id, proc_id = nil)
      @claim_id = claim_id
      @proc_id = proc_id

      # Early exit optimization - prevents unnecessary service calls
      return if claim_group_failed?

      create_form_submission_attempt
      response = submit_to_service

      if response.success?
        handle_job_success
      else
        handle_job_failure(response.error)
      end
    rescue => e
      handle_job_failure(e.message)
    end

    private

    attr_reader :claim_id, :proc_id

    ##
    # Service-specific submission logic - BGS vs Lighthouse vs Fax
    # @return [ServiceResponse] Must respond to success? and error methods
    def submit_to_service
      raise NotImplementedError, 'Subclasses must implement submit_to_service'
    end

    # Prevents wasted work when sibling jobs have determined failure
    def claim_group_failed?
      # TODO: Implement actual check against ClaimGroup model
      false
    end

    def claim_group_completed?
      # TODO: Implement actual check against ClaimGroup model (failed or succeeded)
      false
    end

    # Override for service-specific permanent failures (INVALID_SSN, DUPLICATE_CLAIM, etc)
    def permanent_failure?(error)
      return false if error.nil?

      false # Base: assume all errors are transient
    end

    # Atomic updates prevent partial state corruption
    def handle_job_success
      ActiveRecord::Base.transaction do
        mark_job_succeeded
        update_parent_if_appropriate
      end
    end

    def mark_job_succeeded
      form_submission_attempt.succeed!

      # TODO: Update claim_group status (this job only)
    end

    # Pessimistic locking prevents race conditions with sibling jobs
    def update_parent_if_appropriate
      return false if claim_group_completed?

      # TODO: Implement actual parent claim group update logic.
      # Should LOCK the claim group record to prevent race conditions
      # Should send success email notification
      # Should NOT update parent claim if its status is already FAILED
      true
    end

    # Distinguishes permanent vs transient failures for retry logic
    def handle_job_failure(error)
      mark_attempt_failed(error)

      if permanent_failure?(error)
        # Skip Sidekiq retries for permanent failures
        handle_permanent_failure(claim_id, proc_id, error)
        raise Sidekiq::JobRetry::Skip
      end

      # Re-raise for Sidekiq retry mechanism
      raise error
    end

    def mark_attempt_failed(error)
      ActiveRecord::Base.transaction do
        form_submission_attempt.update!(error_message: error)
        form_submission_attempt.fail!
      end
    end

    # Called from retries_exhausted callback OR permanent failure detection
    # CRITICAL: Recreates instance state since callback runs outside job context
    def handle_permanent_failure(claim_id, proc_id, exception)
      @claim_id = claim_id
      @proc_id = proc_id

      ActiveRecord::Base.transaction do
        mark_submission_records_failed(exception)
        mark_claim_groups_failed
      end

      monitor.log_permanent_failure
    rescue
      # Last resort if database updates fail
      monitor.log_silent_failure
    end

    def mark_submission_records_failed(exception)
      return unless @form_submission_attempt

      error_message = "Job exhausted after retries: #{exception.message}"
      @form_submission_attempt.update!(error_message:)
      @form_submission_attempt.fail!
    end

    # Coordinates failure across child and parent claim groups
    def mark_claim_groups_failed
      # TODO: Implement actual claim group failure logic
      # Should update this claim group status to FAILED
      # Should update parent claim group status to FAILED
      # If parent already FAILED, do not update
      # Should LOCK the claim group record to prevent race conditions
      # Should send failure email notification
      true
    end

    # Override for service-specific FormSubmission types (LighthouseFormSubmission, etc)
    def find_or_create_form_submission
      FormSubmission.find_or_create_by(
        form_type: self.class.name.demodulize,
        saved_claim_id: claim_id,
        user_account_id: saved_claim.user_account_id
      )
    end

    # Each retry gets its own attempt record for debugging
    def create_form_submission_attempt
      @form_submission_attempt = FormSubmissionAttempt.create(form_submission:)
      @form_submission_attempt
    end

    # Memoized accessors prevent repeated database queries
    def saved_claim
      @saved_claim ||= DependentsBenefits::SavedClaim.find(@claim_id)
    end

    def form_submission
      @form_submission ||= find_or_create_form_submission
    end

    def form_submission_attempt
      @form_submission_attempt ||= create_form_submission_attempt
    end

    def claim_group
      # TODO: Return ClaimGroup model instance for this claim
    end

    def parent_claim_group
      # TODO: Return parent ClaimGroup model instance
    end

    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end

    def stats_key
      'api.dependents_benefits.submission_job'
    end
  end
end
