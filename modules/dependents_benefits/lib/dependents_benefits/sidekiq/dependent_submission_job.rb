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
    # https://github.com/sidekiq/sidekiq/wiki/Advanced-Options#jobs
    sidekiq_options retry: 16, dead: false

    # Callback runs outside job context - must recreate instance state
    sidekiq_retries_exhausted do |msg, exception|
      claim_id, _proc_id = msg['args']
      new.send(:handle_permanent_failure, claim_id, exception)
    end

    def perform(claim_id, proc_id = nil)
      @claim_id = claim_id
      @proc_id = proc_id

      # Early exit optimization - prevents unnecessary service calls
      return if claim_group_failed?

      create_form_submission_attempt
      response = submit_to_service

      if response&.success?
        handle_job_success
      else
        handle_job_failure(response)
      end
    rescue => e
      handle_job_failure(e)
    end

    private

    attr_reader :claim_id, :proc_id

    ##
    # Service-specific submission logic - BGS vs Lighthouse vs Fax
    # @return [ServiceResponse] Must respond to success? and error methods
    def submit_to_service
      raise NotImplementedError, 'Subclasses must implement submit_to_service'
    end

    # Use .find_or_create to generate/return memoized service-specific form submission record
    # @return [LighthouseFormSubmission, BGSFormSubmission] instance
    def find_or_create_form_submission
      raise NotImplementedError, 'Subclasses must implement find_or_create_form_submission'
    end

    # Generate a new form submission attempt record
    # Each retry gets its own attempt record for debugging
    # @return [LighthouseFormSubmissionAttempt, BGSFormSubmissionAttempt] instance
    def create_form_submission_attempt
      raise NotImplementedError, 'Subclasses must implement create_form_submission_attempt'
    end

    # Memoized accessor for service-specific SavedClaim subclass record
    # @return [Class<DependentsBenefits::SavedClaim>] DependentsBenefits::SavedClaim subclass
    def saved_claim
      raise NotImplementedError, 'Subclasses must implement saved_claim'
    end

    # Service-specific success logic
    # Update submission attempt and form submission records
    # Update claim group status for this child claim if all form submission jobs succeeded
    def mark_job_succeeded
      raise NotImplementedError, 'Subclasses must implement mark_job_succeeded'
    end

    # Service-specific failure logic
    # Update submission attempt record only with failure and error details
    def mark_submission_attempt_failed(exception)
      raise NotImplementedError, 'Subclasses must implement mark_submission_attempt_failed'
    end

    # Service-specific failure logic for permanent failures
    # Update form submission record to failed
    def mark_submission_failed(exception)
      raise NotImplementedError, 'Subclasses must implement mark_submission_failed'
    end

    # Atomic updates prevent partial state corruption
    def handle_job_success
      ActiveRecord::Base.transaction do
        mark_job_succeeded
        update_parent_if_appropriate
      end
    end

    # Distinguishes permanent vs transient failures for retry logic
    def handle_job_failure(error)
      if permanent_failure?(error)
        # Skip Sidekiq retries for permanent failures
        handle_permanent_failure(claim_id, error)
        raise Sidekiq::JobRetry::Skip
      end

      mark_submission_attempt_failed(error)

      # Re-raise for Sidekiq retry mechanism
      raise error
    end

    # Called from retries_exhausted callback OR permanent failure detection
    # CRITICAL: Recreates instance state since callback runs outside job context
    def handle_permanent_failure(claim_id, exception)
      # Reset claim_id class variable for if this was called from sidekiq_retries_exhausted
      @claim_id = claim_id
      ActiveRecord::Base.transaction do
        mark_submission_attempt_failed(exception)
        mark_submission_failed(exception)
        mark_claim_groups_failed_and_notify
      end

      monitor.log_silent_failure_avoided({ claim_id: })
    rescue
      # Last resort if database updates fail
      monitor.log_silent_failure({ claim_id: })
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

    # Pessimistic locking prevents race conditions with sibling jobs
    def update_parent_if_appropriate
      return false if claim_group_completed?

      # TODO: Implement actual parent claim group update logic.
      # Should LOCK the claim group record to prevent race conditions
      # Should send success email notification
      # Should NOT update parent claim if its status is already FAILED
      true
    end

    # Coordinates failure across child and parent claim groups
    def mark_claim_groups_failed_and_notify
      # TODO: Implement actual claim group failure logic
      # Should update this claim group status to FAILED
      # Should update parent claim group status to FAILED
      # If parent already FAILED, do not update
      # Should LOCK the claim group record to prevent race conditions
      # Should send failure email notification
      true
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
