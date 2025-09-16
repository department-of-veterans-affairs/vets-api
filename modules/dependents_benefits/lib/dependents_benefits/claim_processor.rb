# frozen_string_literal: true

require 'dependents_benefits/monitor'

module DependentsBenefits
  class ClaimProcessor
    attr_reader :parent_claim_id, :proc_id

    def initialize(parent_claim_id, proc_id)
      @parent_claim_id = parent_claim_id
      @proc_id = proc_id
    end

    # Synchronously enqueue all (async) submission jobs for 686c and 674 claims
    # @param parent_claim_id [Integer] ID of the parent SavedClaim
    # @param proc_id [String] Processing ID for job tracking
    # @return [Hash] Success result with enqueued job count
    # @raise [StandardError] If any submission job fails to enqueue
    def self.enqueue_submissions(parent_claim_id, proc_id)
      processor = new(parent_claim_id, proc_id)
      processor.enqueue_submissions
    end

    def enqueue_submissions
      monitor.track_processor_info('Starting claim submission processing', 'start', { parent_claim_id: })
      jobs_enqueued = 0
      collect_child_claims.each do |claim|
        case claim.form_id
        when '21-686C'
          jobs_enqueued += enqueue_686c_submission(claim)
        when '21-674'
          jobs_enqueued += enqueue_674_submission(claim)
        else
          monitor.track_processor_error('Unknown form_id for child claim', 'unknown_form',
                                        { parent_claim_id:, claim_id: claim.id, form_id: claim.form_id })
        end
      end
      monitor.track_processor_info('Successfully enqueued all submission jobs', 'enqueue_success',
                                   { parent_claim_id:, jobs_count: jobs_enqueued })
      { data: { jobs_enqueued: }, error: nil }
    rescue => e
      handle_enqueue_failure(e)

      # Re-raise the original error after handling to return to user
      raise e
    end

    private

    def collect_child_claims
      # TODO: Implement logic to collect childs claim ids based on parent_claim_id
      claim_ids = []
      child_claims = SavedClaim.where(id: claim_ids)
      # TODO: raise StandardError, "No child claims found for parent claim #{parent_claim_id}" if child_claims.empty?

      monitor.track_processor_info('Collected child claims for processing', 'collect_children',
                                   { parent_claim_id:, child_claims_count: child_claims.count })

      child_claims
    end

    def enqueue_686c_submission(claim)
      jobs_count = 0

      # Enqueue primary 686c submission job
      # TODO: Add calls to submission jobs here as they are implemented
      # Example: DependentsBenefits::SubmissionJob.perform_async(claim.id, proc_id)
      # jobs_count += 1

      monitor.track_processor_info('Enqueued 686c submission jobs', 'enqueue_686c',
                                   { parent_claim_id:, claim_id: claim.id })

      jobs_count
    end

    def enqueue_674_submission(claim)
      jobs_count = 0

      # Enqueue primary 674 submission job
      # TODO: Add calls to submission jobs here as they are implemented
      # Example: DependentsBenefits::SubmissionJob.perform_async(claim.id, proc_id)
      # jobs_count += 1

      monitor.track_processor_info('Enqueued 674 submission jobs', 'enqueue_674',
                                   { parent_claim_id:, claim_id: claim.id })

      jobs_count
    end

    def handle_enqueue_failure(error)
      monitor.track_processor_error('Failed to enqueue submission jobs', 'enqueue_failure',
                                    { parent_claim_id:, error: error.message })

      # TODO: Update parent ClaimGroup status to FAILED
    rescue => e
      monitor.track_processor_error('Failed to update ClaimGroup status', 'status_update',
                                    { parent_claim_id:, error: e.message, original_error: error.message })
    end

    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end
  end
end
