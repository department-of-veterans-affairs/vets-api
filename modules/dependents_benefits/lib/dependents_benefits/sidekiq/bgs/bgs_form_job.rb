# frozen_string_literal: true

require 'dependents_benefits/service_response'
require 'dependents_benefits/sidekiq/dependent_submission_job'
require 'bgs/job'
require 'bgs/form686c'
require 'bgs/form674'

module DependentsBenefits
  # Background jobs for dependent benefits claim processing
  module Sidekiq
    # Submodule for BGS-related submission jobs
    module BGS
      ##
      # Submission job for dependent benefits forms via BGS
      #
      # Handles the submission of dependent benefits forms (674, 686c) to BGS (Benefits
      # Gateway Service). Normalizes claim data, validates the claim, and submits to
      # BGS using the appropriate BGS service. Detects permanent BGS errors for
      # appropriate retry behavior.
      #
      # This is an abstract base class that requires subclasses to implement:
      # - {#submit_686c_form}
      # - {#submit_674_form}
      # @abstract Subclasses must implement abstract methods
      # @see DependentSubmissionJob
      # @see BGS::Submission
      # @see BGS::SubmissionAttempt
      #
      class BGSFormJob < DependentSubmissionJob
        ##
        # Submit all child claims to BGS
        #
        # @return [void]
        # @raise [DependentSubmissionError] if any claim submission fails
        def submit_claims_to_service
          @proc_id = generate_proc_id
          child_claims.each do |claim|
            service_response = submit_claim_to_service(claim)
            raise DependentSubmissionError, service_response&.error unless service_response&.success?
          end
          DependentsBenefits::ServiceResponse.new(status: true)
        end

        ##
        # Submit a 686c form to BGS
        #
        # @param claim [SavedClaim] The 686c claim to submit
        # @return [void]
        def submit_686c_form(claim)
          claim_data = ::BGS::Job.new.normalize_names_and_addresses!(claim.parsed_form)

          ::BGS::Form686c.new(generate_user_struct, claim, { proc_id: @proc_id }).submit(claim_data)
        end

        ##
        # Submit a 674 form to BGS
        #
        # @param claim [SavedClaim] The 674 claim to submit
        # @return [void]
        def submit_674_form(claim)
          claim_data = ::BGS::Job.new.normalize_names_and_addresses!(claim.parsed_form)

          ::BGS::Form674.new(generate_user_struct, claim, { proc_id: @proc_id }).submit(claim_data)
        end

        private

        ##
        # Generate a BGS proc ID for grouping related submissions
        #
        # @return [String] The generated proc ID
        # @raise [DependentsBenefits::DependentSubmissionError] if proc ID generation fails
        def generate_proc_id
          bgs_service = ::BGS::Service.new(generate_user_struct)

          # vnp_proc is BGS's way of grouping related form submissions together
          vnp_response = bgs_service.create_proc(proc_state: 'Started')
          raise 'BGS proc ID generation failed: No proc ID returned' if vnp_response.nil?

          @proc_id = vnp_response[:vnp_proc_id]

          bgs_service.create_proc_form(@proc_id, ADD_REMOVE_DEPENDENT.downcase) if saved_claim.submittable_686?
          bgs_service.create_proc_form(@proc_id, SCHOOL_ATTENDANCE_APPROVAL) if saved_claim.submittable_674?

          @proc_id
        rescue => e
          monitor.track_submission_error('Error generating proc ID', 'proc_id_failure', error: e, parent_claim_id:)
          raise DependentsBenefits::Sidekiq::DependentSubmissionError, e
        end

        ##
        # Finds or creates a BGS form submission record
        #
        # Uses find_or_create_by to generate or return a memoized service-specific
        # form submission record. The record is keyed by form_id and saved_claim_id.
        #
        # @param claim [SavedClaim] The claim to find or create a submission for
        # @return [BGS::Submission] The submission record (memoized)
        def find_or_create_form_submission(claim)
          ::BGS::Submission.find_or_create_by(form_id: claim.form_id, saved_claim_id: claim.id)
        end

        ##
        # Check if a submission has already succeeded
        #
        # @param submission [BGS::Submission] The form submission record to check
        # @return [Boolean] true if submission has a non-failure attempt
        def submission_previously_succeeded?(submission)
          submission&.non_failure_attempt.present?
        end

        ##
        # Generates a new form submission attempt record
        #
        # Each retry gets its own attempt record for debugging and tracking purposes.
        # The attempt is associated with the parent submission record.
        #
        # @param submission [BGS::Submission] The submission to create an attempt for
        # @return [BGS::SubmissionAttempt] The newly created attempt record (memoized)
        def create_form_submission_attempt(submission)
          ::BGS::SubmissionAttempt.create(submission:)
        end

        ##
        # Marks the submission attempt as successful
        #
        # Service-specific success logic - updates the submission attempt record to
        # success status. Called after successful BGS submission.
        #
        # @param submission_attempt [BGS::SubmissionAttempt] The attempt to mark as succeeded
        # @return [Boolean, nil] Result of status update, or nil if attempt doesn't exist
        def mark_submission_attempt_succeeded(submission_attempt)
          submission_attempt&.success!
        end

        ##
        # Marks the submission attempt as failed with error details
        #
        # Service-specific failure logic - updates the submission attempt record with
        # failure status and stores the exception details for debugging.
        #
        # @param exception [Exception] The exception that caused the failure
        # @return [Boolean, nil] Result of status update, or nil if attempt doesn't exist
        def mark_submission_attempt_failed(submission_attempt, exception)
          submission_attempt&.fail!(error: exception)
        end

        ##
        # No-op for BGS submissions
        #
        # BGS::Submission records do not have a status field, so this method is a no-op.
        # This differs from other submission types (e.g., EVSS), which may require
        # status updates on the submission record itself when a failure occurs.
        #
        # @param _exception [Exception] The exception that caused the failure (unused)
        # @return [nil]
        def mark_submission_failed(_exception) = nil

        ##
        # Determines if an error represents a permanent BGS failure
        #
        # Checks if the error message or its cause matches any of the BGS filtered errors
        # that should not be retried (e.g., invalid SSN, duplicate claim, invalid data).
        # Permanent failures will not trigger job retries, while transient errors will.
        #
        # @param error [Exception, nil] The error to check
        # @return [Boolean] true if error matches BGS permanent failure patterns, false if transient or nil
        # @see BGS::Job::FILTERED_ERRORS
        def permanent_failure?(error)
          return false if error.nil?

          ::BGS::Job::FILTERED_ERRORS.any? { |filtered| error.message.include?(filtered) || error.cause&.message&.include?(filtered) }
        end
      end
    end
  end
end
