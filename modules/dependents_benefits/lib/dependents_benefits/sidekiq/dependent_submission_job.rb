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
      parent_claim_group.status == 'FAILED'
    end

    def claim_group_completed?
      parent_claim_group.status.in?(%w[FAILED SUCCEEDED])
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
      claim_group.update!(status: 'SUCCEEDED')
    end

    # Pessimistic locking prevents race conditions with sibling jobs
    def update_parent_if_appropriate
      return if claim_group_completed?

      parent_claim_group.with_lock do
        parent_claim_group.mark_succeeded_and_notify! if claim_group.all_siblings_succeeded?
      end
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
      form_submission_attempt.update!(error_message: error)
      form_submission_attempt.fail!
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
      claim_group&.update!(status: 'FAILED')

      parent_claim_group.with_lock do
        # Prevent duplicate notifications
        parent_claim_group.mark_failed_and_notify! unless parent_claim_group.status == 'FAILED'
      end
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

    # TODO: Replace MockClaimGroup with actual ClaimGroup model
    def claim_group
      @claim_group ||= DependentsBenefits::MockClaimGroup.new(
        parent_claim_id: 123, claim_id:
      )
    end

    def parent_claim_group
      @parent_claim_group ||= DependentsBenefits::MockClaimGroup.new(
        parent_claim_id: 123, claim_id: 123
      )
    end

    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end

    def stats_key
      'api.dependents_benefits.submission_job'
    end
  end
end
