# frozen_string_literal: true

module DependentsBenefits::Sidekiq
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
    include ::Sidekiq::Job

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
      return if parent_group_failed?

      find_or_create_form_submission
      create_form_submission_attempt
      @service_response = submit_to_service

      if @service_response&.success?
        handle_job_success
      else
        handle_job_failure(@service_response&.error)
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

    # Service-specific success logic
    # Update submission attempt and form submission records
    def mark_submission_succeeded
      raise NotImplementedError, 'Subclasses must implement mark_submission_succeeded'
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
        parent_group.with_lock do
          mark_submission_succeeded # update attempt and submission records (ie FormSubmission)

          # update current child claim group if all its submissions succeeded
          mark_current_group_succeeded if all_current_group_submissions_succeeded?

          # if all of the child claim groups succeeded, and the parent claim group hasn't failed
          if all_child_groups_succeeded? && !parent_group_completed?
            # update parent claim group status
            mark_parent_group_succeeded
            # notify user of overall success
            send_success_notification
          end
        end
      end
    rescue => e
      monitor.track_submission_error('Error handling job success', 'success_failure', error: e)
    end

    def all_child_groups_succeeded?
      SavedClaimGroup.child_claims_for(parent_claim_id).all?(&:succeeded?)
    end

    # Distinguishes permanent vs transient failures for retry logic
    def handle_job_failure(error)
      monitor.track_submission_error("Error submitting #{self.class}", 'error', error:)
      mark_submission_attempt_failed(error)

      if permanent_failure?(error)
        # Skip Sidekiq retries for permanent failures
        handle_permanent_failure(claim_id, error)
        raise ::Sidekiq::JobRetry::Skip
      end

      case error
      when Exception
        # Re-raise actual exceptions for Sidekiq retry mechanism
        raise error
      when nil
        # Handle nil case
        raise StandardError, 'Unknown error occurred during job execution'
      else
        # Handle non-exception errors
        raise StandardError, error
      end
    end

    # Called from retries_exhausted callback OR permanent failure detection
    # CRITICAL: Recreates instance state since callback runs outside job context
    def handle_permanent_failure(claim_id, exception)
      # Reset claim_id class variable for if this was called from sidekiq_retries_exhausted
      @claim_id = claim_id
      ActiveRecord::Base.transaction do
        parent_group.with_lock do
          mark_submission_failed(exception)
          mark_current_group_failed

          unless parent_group_completed?
            mark_parent_group_failed
            send_backup_job
          end
        end
      end
    rescue => e
      begin
        send_failure_notification
        monitor.log_silent_failure_avoided({ claim_id:, error: e })
      rescue => e
        # Last resort notification fails
        monitor.log_silent_failure({ claim_id:, error: e })
      end
    end

    # Prevents wasted work when sibling jobs have determined failure
    # If the parent claim group is already failed, all jobs are considered failed
    def parent_group_failed?
      parent_group&.failed?
    end

    # Check if parent claim group already completed (failed or succeeded)
    def parent_group_completed?
      parent_group&.completed?
    end

    # Override for service-specific permanent failures (INVALID_SSN, DUPLICATE_CLAIM, etc)
    def permanent_failure?(error)
      return false if error.nil?

      false # Base: assume all errors are transient
    end

    def all_current_group_submissions_succeeded?
      saved_claim.submissions_succeeded?
    end

    def mark_current_group_succeeded
      current_group&.update!(status: SavedClaimGroup::STATUSES[:SUCCESS])
    end

    def mark_current_group_failed
      current_group&.update!(status: SavedClaimGroup::STATUSES[:FAILURE])
    end

    def mark_parent_group_succeeded
      parent_group&.update!(status: SavedClaimGroup::STATUSES[:SUCCESS])
    end

    def mark_parent_group_failed
      parent_group&.update!(status: SavedClaimGroup::STATUSES[:FAILURE])
    end

    def send_success_notification
      DependentsBenefits::NotificationEmail.new(claim_id).deliver(:submitted)
    rescue => e
      monitor.track_error_event('Error sending success notification email', 'notification_failure', error: e)
    end

    def send_failure_notification
      DependentsBenefits::NotificationEmail.new(claim_id).deliver(:error)
    rescue => e
      monitor.track_error_event('Error sending failure notification email', 'notification_failure', error: e)
    end

    def send_backup_job
      # TODO
    end

    def current_group
      SavedClaimGroup.by_saved_claim_id(claim_id).first!
    end

    def parent_group
      SavedClaimGroup.by_saved_claim_id(parent_claim_id).first!
    end

    def saved_claim
      @saved_claim ||= ::SavedClaim.find(claim_id)
    end

    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end

    def parent_claim_id
      @parent_claim_id ||= current_group&.parent_claim_id
    end

    def user_data
      @user_data ||= JSON.parse(parent_group.user_data)
    end

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
  end
end
