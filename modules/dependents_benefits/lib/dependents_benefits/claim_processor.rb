# frozen_string_literal: true

require 'dependents_benefits/sidekiq/bgs/bgs_form_job'
require 'dependents_benefits/sidekiq/claims_evidence/claims_evidence_form_job'
require 'dependents_benefits/monitor'

module DependentsBenefits
  ##
  # Processes dependent benefit claims and coordinates submission jobs
  #
  # Handles the creation of child claims (686c, 674) from parent claims and
  # orchestrates the enqueueing of submission jobs to multiple services (BGS, Claims).
  # Tracks submission status and handles failures during the enqueueing process.
  #
  class ClaimProcessor
    attr_reader :parent_claim_id

    # Initializes a new ClaimProcessor
    #
    # @param parent_claim_id [Integer] ID of the parent SavedClaim
    def initialize(parent_claim_id)
      @parent_claim_id = parent_claim_id
    end

    # Synchronously enqueues all (async) submission jobs for 686c and 674 claims
    #
    # Factory method that instantiates a processor and triggers submission job
    # enqueueing for a parent claim and its child claims.
    #
    # @param parent_claim_id [Integer] ID of the parent SavedClaim
    # @return [Hash] Success result with :jobs_enqueued count and :error nil
    # @raise [StandardError] If any submission job fails to enqueue
    def self.enqueue_submissions(parent_claim_id)
      processor = new(parent_claim_id)
      processor.enqueue_submissions
    end

    # Enqueues submission jobs for all child claims
    #
    # Enqueues BGS and Claims Evidence submission jobs for the parent claim.
    # Tracks the number of jobs enqueued and handles failures by updating parent claim
    # group status.
    #
    # @return [Hash] Success result with :jobs_enqueued count and :error nil
    # @raise [StandardError] If enqueueing fails
    def enqueue_submissions
      monitor.track_processor_info('Starting claim submission processing', 'start', parent_claim_id:)

      jobs_enqueued = 0
      DependentsBenefits::Sidekiq::BGS::BGSFormJob.perform_async(parent_claim_id)
      jobs_enqueued += 1
      DependentsBenefits::Sidekiq::ClaimsEvidence::ClaimsEvidenceFormJob.perform_async(parent_claim_id)
      jobs_enqueued += 1

      monitor.track_processor_info('Successfully enqueued all submission jobs', 'enqueue_success',
                                   parent_claim_id:, jobs_count: jobs_enqueued)
      record_enqueue_completion
      { data: { jobs_enqueued: }, error: nil }
    rescue => e
      handle_enqueue_failure(e)

      # Re-raise the original error after handling to return to user
      raise e
    end

    # Collects all child claims associated with the parent claim
    #
    # Retrieves child claim IDs from SavedClaimGroup and loads the corresponding
    # SavedClaim records. Raises error if no child claims are found.
    #
    # @return [ActiveRecord::Relation<SavedClaim>] Collection of child claims
    # @raise [StandardError] if no child claims found for parent claim
    def collect_child_claims
      return @child_claims if @child_claims

      claim_ids = SavedClaimGroup.child_claims_for(parent_claim_id).pluck(:saved_claim_id)
      @child_claims = ::SavedClaim.where(id: claim_ids)
      raise StandardError, "No child claims found for parent claim #{parent_claim_id}" if child_claims.empty?

      monitor.track_processor_info('Collected child claims for processing', 'collect_children',
                                   parent_claim_id:, child_claims_count: child_claims.count)

      @child_claims
    end

    # Handle permanent submission failure
    #
    # Marks parent group as failed and enqueues backup job if not already completed.
    # Sends error notification if transaction fails.
    #
    # @param exception [Exception] The exception that caused the failure
    # @return [void]
    def handle_permanent_failure(exception)
      monitor.track_processor_error("Error submitting #{self.class}", 'error.permanent', error: exception,
                                                                                         parent_claim_id:)
      ActiveRecord::Base.transaction do
        parent_claim_group.with_lock do
          unless parent_claim_group&.completed?
            mark_parent_claim_group_failed
            send_backup_job
          end
        end
      end
    rescue => e
      begin
        notification_email.send_error_notification
        monitor.log_silent_failure_avoided({ parent_claim_id:, error: e })
      rescue => e
        # Last resort if notification fails
        monitor.log_silent_failure({ parent_claim_id:, error: e })
      end
    end

    # Handle successful submission of all child claims
    #
    # Checks if all child claims succeeded and marks parent group as succeeded.
    # Sends received notification to veteran.
    #
    # @return [void]
    def handle_successful_submission
      monitor.track_processor_info('Checking if claim submissions succeeded', 'success_check', parent_claim_id:)

      ActiveRecord::Base.transaction do
        parent_claim_group.with_lock do
          if child_claims.all?(&:submissions_succeeded?) && !parent_claim_group.completed?
            monitor.track_processor_info('All claim submissions succeeded', 'success', parent_claim_id:)
            mark_parent_claim_group_succeeded
            notification_email.send_received_notification
          end
        end
      end
    rescue => e
      monitor.track_processor_error("Error handling successful submission for #{self.class}", 'success.error',
                                    error: e, parent_claim_id:)
    end

    private

    # Handles failures during submission job enqueueing
    #
    # Logs the error and marks the parent claim group as FAILURE. If updating
    # the claim group status also fails, logs that error as well.
    #
    # @param error [Exception] The error that occurred during enqueueing
    # @return [void]
    def handle_enqueue_failure(error)
      monitor.track_processor_error('Failed to enqueue submission jobs', 'enqueue_failure',
                                    parent_claim_id:, error: error.message)

      parent_claim_group.update!(status: SavedClaimGroup::STATUSES[:FAILURE])
    rescue => e
      monitor.track_processor_error('Failed to update ClaimGroup status', 'status_update',
                                    parent_claim_id:, error: e.message)
    end

    # Records successful enqueueing by updating claim group status
    #
    # Marks the claim group as ACCEPTED after jobs are successfully enqueued.
    # Currently unused but available for future implementation.
    #
    # @return [Boolean, nil] Result of the update, or nil if claim group not found
    def record_enqueue_completion
      parent_claim_group&.update!(status: SavedClaimGroup::STATUSES[:ACCEPTED])
    end

    # Returns a memoized instance of the DependentsBenefits monitor
    #
    # @return [DependentsBenefits::Monitor] Monitor instance for tracking events and errors
    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end

    # Enqueues a backup submission job for the parent claim
    #
    # @return [String] Sidekiq job ID
    def send_backup_job
      DependentsBenefits::Sidekiq::DependentBackupJob.perform_async(parent_claim_id)
    end

    # Returns a notification email handler for the claim
    #
    # @return [DependentsBenefits::NotificationEmail] Notification email instance
    def notification_email
      @notification_email ||= DependentsBenefits::NotificationEmail.new(parent_claim_id)
    end

    # Returns the parent claim group
    #
    # @return [SavedClaimGroup, nil] The parent claim group record
    def parent_claim_group
      @parent_claim_group ||= SavedClaimGroup.find_by(parent_claim_id:, saved_claim_id: parent_claim_id)
    end

    # Marks the parent claim group as succeeded
    #
    # @return [Boolean] result of the update operation
    def mark_parent_claim_group_succeeded
      parent_claim_group&.update!(status: SavedClaimGroup::STATUSES[:SUCCESS])
    end

    # Marks the parent claim group as failed
    #
    # @return [Boolean] result of the update operation
    def mark_parent_claim_group_failed
      parent_claim_group&.update!(status: SavedClaimGroup::STATUSES[:FAILURE])
    end

    # Collects a memoized list of child claims
    # @return [Array<DependentClaim>]
    def child_claims
      @child_claims ||= collect_child_claims
    end
  end
end
