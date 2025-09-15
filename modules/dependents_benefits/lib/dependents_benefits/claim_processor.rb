# frozen_string_literal: true

require 'dependents_benefits/monitor'

module DependentsBenefits
  class ClaimProcessor
    attr_reader :parent_claim_id, :proc_id

    STATSD_KEY_PREFIX = 'api.dependents_benefits_processor'

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
      monitor.track_info_event('Starting claim submission processing', "#{STATSD_KEY_PREFIX}.start",
                               { parent_claim_id:, proc_id: })

      child_claims = collect_child_claims
      jobs_enqueued = 0

      begin
        # Enqueue 686c submission jobs
        form_686c_claims = child_claims.select { |claim| claim.form_id == '21-686C' }
        jobs_enqueued += enqueue_686c_submissions(form_686c_claims)

        # Enqueue 674 submission jobs
        form_674_claims = child_claims.select { |claim| claim.form_id == '21-674' }
        jobs_enqueued += enqueue_674_submissions(form_674_claims)

        monitor.track_info_event('Successfully enqueued all submission jobs', "#{STATSD_KEY_PREFIX}.enqueue_success",
                                 { parent_claim_id:, jobs_count: jobs_enqueued, proc_id: })

        { data: { jobs_enqueued: }, error: nil }
      rescue => e
        handle_enqueue_failure(e)

        # Re-raise the original error after handling to return to user
        raise e
      end
    end

    private

    def collect_child_claims
      # TODO: Implement logic to collect childs claim ids based on parent_claim_id
      claim_ids = []
      child_claims = SavedClaim.where(id: claim_ids)
      # TODO: raise StandardError, "No child claims found for parent claim #{parent_claim_id}" if child_claims.empty?

      monitor.track_info_event('Collected child claims for processing', "#{STATSD_KEY_PREFIX}.collect_children",
                               { parent_claim_id:, child_claims_count: child_claims.count, proc_id: })

      child_claims
    end

    def enqueue_686c_submissions(form_686c_claims)
      jobs_count = 0

      # There should only be one 686c claim per parent, but handle multiple just in case
      form_686c_claims.each do |claim|
        # Enqueue primary 686c submission job
        # TODO: Add calls to submission jobs here as they are implemented
        # Example: DependentsBenefits::SubmissionJob.perform_async(claim.id, proc_id)
        # jobs_count += 1

        monitor.track_info_event('Enqueued 686c submission jobs', "#{STATSD_KEY_PREFIX}.enqueue_686c",
                                 { parent_claim_id:, claim_id: claim.id, proc_id: })
      end

      jobs_count
    end

    def enqueue_674_submissions(form_674_claims)
      jobs_count = 0

      form_674_claims.each do |claim|
        # Enqueue primary 674 submission job
        # TODO: Add calls to submission jobs here as they are implemented
        # Example: DependentsBenefits::SubmissionJob.perform_async(claim.id, proc_id)
        # jobs_count += 1

        monitor.track_info_event('Enqueued 674 submission jobs', "#{STATSD_KEY_PREFIX}.enqueue_674",
                                 { parent_claim_id:, claim_id: claim.id, proc_id: })
      end

      jobs_count
    end

    def handle_enqueue_failure(error)
      monitor.track_error_event('Failed to enqueue submission jobs', "#{STATSD_KEY_PREFIX}.enqueue_failure",
                                { parent_claim_id:, error: error.message, proc_id: })

      # TODO: Update parent ClaimGroup status to FAILED
    rescue => e
      monitor.track_error_event('Failed to update ClaimGroup status', "#{STATSD_KEY_PREFIX}.status_update_failure",
                                { parent_claim_id:, error: e.message, original_error: error.message, proc_id: })
    end

    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end
  end
end
