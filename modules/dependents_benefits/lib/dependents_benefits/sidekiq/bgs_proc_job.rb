# frozen_string_literal: true

require 'dependents_benefits/monitor'
require 'dependents_benefits/service_response'
require 'dependents_benefits/sidekiq/dependent_submission_job'
require 'bgs/job'
require 'bgsv2/form686c'

module DependentsBenefits
  module Sidekiq
    class BGSProcJob < DependentSubmissionJob
      ##
      # Creates a BGS vnp_proc (Veteran Notification Process) and associates form submissions
      # The proc_id is used to track all related form submissions for this veteran's request
      # @return [ServiceResponse] Must respond to success? and error methods
      def submit_to_service
        @parent_claim_id = @claim_id
        bgs_service = BGSV2::Service.new(generate_user_struct)

        # vnp_proc is BGS's way of grouping related form submissions together
        vnp_response = bgs_service.create_proc(proc_state: 'Started')
        @proc_id = vnp_response[:vnp_proc_id]

        bgs_service.create_proc_form(@proc_id, ADD_REMOVE_DEPENDENT.downcase) if saved_claim.submittable_686?
        bgs_service.create_proc_form(@proc_id, SCHOOL_ATTENDANCE_APPROVAL) if saved_claim.submittable_674?

        DependentsBenefits::ServiceResponse.new(status: true, data: { proc_id: @proc_id })
      rescue => e
        DependentsBenefits::ServiceResponse.new(status: false, error: e)
      end

      private

      ##
      # Following proc_id and proc_form success, trigger the enqueueing of child claim submissions
      def handle_job_success
        mark_submission_succeeded # update attempt and submission records
        # Enqueue follow-up jobs to submit individual forms associated with this claim and proc_id
        DependentsBenefits::ClaimProcessor.enqueue_submissions(@parent_claim_id, @proc_id)
      rescue => e
        monitor.track_submission_error('Error handling job success', 'success_failure', error: e)
        send_backup_job
      end

      # Use .find_or_create to generate/return memoized service-specific form submission record
      # @return [BGSFormSubmission] instance
      def find_or_create_form_submission
        @submission ||= BGS::Submission.find_or_create_by(form_id: '686C-674', saved_claim_id: saved_claim.id)
      end

      def submission
        @submission ||= find_or_create_form_submission
      end

      # Generate a new form submission attempt record
      # Each retry gets its own attempt record for debugging
      # @return [BGSFormSubmissionAttempt] instance
      def create_form_submission_attempt
        @submission_attempt ||= BGS::SubmissionAttempt.create(submission:)
      end

      def submission_attempt
        @submission_attempt ||= create_form_submission_attempt
      end

      # Update submission attempt and form submission records
      def mark_submission_succeeded
        submission_attempt&.success!
      end

      # Update submission attempt record only with failure and error details
      def mark_submission_attempt_failed(exception)
        submission_attempt&.fail!(error: exception)
      end

      ##
      # BGS::Submission has no status update, so no-op here
      # This differs from other submission types, which may require status updates on failure.
      def mark_submission_failed(_exception) = nil

      #
      # We don't yet know which errors are permanent failures for proc jobs.
      # This allows the job to retry on all error types rather than skipping retries for certain errors.
      def permanent_failure?(_error)
        false
      end
    end
  end
end
