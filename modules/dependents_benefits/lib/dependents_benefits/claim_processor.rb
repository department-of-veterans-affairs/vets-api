# frozen_string_literal: true

require 'dependents_benefits/sidekiq/bgs_proc_job'
require 'dependents_benefits/sidekiq/bgs_674_job'
require 'dependents_benefits/sidekiq/bgs_686c_job'
require 'dependents_benefits/sidekiq/claims_686c_job'
require 'dependents_benefits/sidekiq/claims_674_job'
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
    attr_reader :parent_claim_id, :proc_id

    # Initializes a new ClaimProcessor
    #
    # @param parent_claim_id [Integer] ID of the parent SavedClaim
    # @param proc_id [String, nil] Optional processing ID for job tracking
    def initialize(parent_claim_id, proc_id)
      @parent_claim_id = parent_claim_id
      @proc_id = proc_id
    end

    # Creates processing forms for a parent claim
    #
    # Factory method that instantiates a processor and triggers form creation.
    #
    # @param parent_claim_id [Integer] ID of the parent SavedClaim
    # @return [String] Sidekiq job ID
    def self.create_proc_forms(parent_claim_id)
      processor = new(parent_claim_id, nil)
      processor.create_proc_forms
    end

    # Enqueues a BGS processing job for the parent claim
    #
    # @return [String] Sidekiq job ID
    def create_proc_forms
      DependentsBenefits::Sidekiq::BGSProcJob.perform_async(parent_claim_id)
    end

    # Synchronously enqueues all (async) submission jobs for 686c and 674 claims
    #
    # Factory method that instantiates a processor and triggers submission job
    # enqueueing for a parent claim and its child claims.
    #
    # @todo Set claim group gets set as accepted
    # @param parent_claim_id [Integer] ID of the parent SavedClaim
    # @param proc_id [String] Processing ID for job tracking
    # @return [Hash] Success result with :jobs_enqueued count and :error nil
    # @raise [StandardError] If any submission job fails to enqueue
    def self.enqueue_submissions(parent_claim_id, proc_id)
      processor = new(parent_claim_id, proc_id)
      processor.enqueue_submissions
    end

    # Enqueues submission jobs for all child claims
    #
    # Collects child claims and enqueues appropriate submission jobs based on form type.
    # Tracks the number of jobs enqueued and handles failures by updating parent claim
    # group status.
    #
    # @return [Hash] Success result with :jobs_enqueued count and :error nil
    # @raise [StandardError] If child claims not found or enqueueing fails
    def enqueue_submissions
      monitor.track_processor_info('Starting claim submission processing', 'start', parent_claim_id:)
      jobs_enqueued = 0
      collect_child_claims.each do |claim|
        case claim.form_id
        when '21-686C'
          jobs_enqueued += enqueue_686c_submission(claim)
        when '21-674'
          jobs_enqueued += enqueue_674_submission(claim)
        else
          monitor.track_processor_error('Unknown form_id for child claim', 'unknown_form',
                                        parent_claim_id:, claim_id: claim.id, form_id: claim.form_id)
        end
      end
      monitor.track_processor_info('Successfully enqueued all submission jobs', 'enqueue_success',
                                   parent_claim_id:, jobs_count: jobs_enqueued)
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
      claim_ids = SavedClaimGroup.child_claims_for(parent_claim_id).pluck(:saved_claim_id)
      child_claims = ::SavedClaim.where(id: claim_ids)
      raise StandardError, "No child claims found for parent claim #{parent_claim_id}" if child_claims.empty?

      monitor.track_processor_info('Collected child claims for processing', 'collect_children',
                                   parent_claim_id:, child_claims_count: child_claims.count)

      child_claims
    end

    private

    # Enqueues submission jobs for a 686c claim
    #
    # Enqueues both BGS and Claims submission jobs for the 686c form.
    #
    # @param claim [SavedClaim] The 686c claim to submit
    # @return [Integer] Number of jobs enqueued (currently 2)
    def enqueue_686c_submission(claim)
      jobs_count = 0

      # Enqueue primary 686c submission jobs
      Sidekiq::BGS686cJob.perform_async(claim.id, proc_id)
      jobs_count += 1

      Sidekiq::Claims686cJob.perform_async(claim.id, proc_id)
      jobs_count += 1

      # @todo Add calls to submission jobs here as they are implemented

      monitor.track_processor_info('Enqueued 686c submission jobs', 'enqueue_686c',
                                   parent_claim_id:, claim_id: claim.id)

      jobs_count
    end

    # Enqueues submission jobs for a 674 claim
    #
    # Enqueues both BGS and Claims submission jobs for the 674 form.
    #
    # @param claim [SavedClaim] The 674 claim to submit
    # @return [Integer] Number of jobs enqueued (currently 2)
    def enqueue_674_submission(claim)
      jobs_count = 0

      # Enqueue primary 674 submission job
      Sidekiq::BGS674Job.perform_async(claim.id, proc_id)
      jobs_count += 1

      Sidekiq::Claims674Job.perform_async(claim.id, proc_id)
      jobs_count += 1

      monitor.track_processor_info('Enqueued 674 submission jobs', 'enqueue_674',
                                   parent_claim_id:, claim_id: claim.id)

      jobs_count
    end

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

      parent_claim_group = SavedClaimGroup.find_by!(parent_claim_id:, saved_claim_id: parent_claim_id)
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
    # @param claim_id [Integer] ID of the child claim
    # @return [Boolean, nil] Result of the update, or nil if claim group not found
    def record_enqueue_completion(claim_id)
      claim_group = SavedClaimGroup.find_by(parent_claim_id:, saved_claim_id: claim_id)
      claim_group&.update!(status: SavedClaimGroup::STATUSES[:ACCEPTED])
    end

    # Returns a memoized instance of the DependentsBenefits monitor
    #
    # @return [DependentsBenefits::Monitor] Monitor instance for tracking events and errors
    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end
  end
end
