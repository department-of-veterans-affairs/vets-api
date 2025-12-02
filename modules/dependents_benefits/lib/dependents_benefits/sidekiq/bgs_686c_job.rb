# frozen_string_literal: true

require 'dependents_benefits/monitor'
require 'dependents_benefits/service_response'
require 'dependents_benefits/sidekiq/dependent_submission_job'
require 'bgs/job'
require 'bgsv2/form686c'

module DependentsBenefits
  module Sidekiq
    ##
    # Submission job for 686c claims via BGS
    #
    # Handles the submission of 686c (Add/Remove Dependent) forms to BGS (Benefits
    # Gateway Service). Normalizes claim data, validates the claim, and submits to
    # BGS using the BGSV2::Form686c service. Detects permanent BGS errors for
    # appropriate retry behavior.
    #
    class BGS686cJob < DependentSubmissionJob
      # Exception raised when 686c claim validation fails
      class Invalid686cClaim < StandardError; end

      ##
      # Service-specific submission logic for BGS
      # @return [ServiceResponse] Must respond to success? and error methods
      def submit_to_service
        saved_claim.add_veteran_info(user_data)

        raise Invalid686cClaim unless saved_claim.valid?(:run_686_form_jobs)

        claim_data = BGS::Job.new.normalize_names_and_addresses!(saved_claim.parsed_form)

        BGSV2::Form686c.new(generate_user_struct, saved_claim, proc_id).submit(claim_data)

        DependentsBenefits::ServiceResponse.new(status: true)
      rescue => e
        DependentsBenefits::ServiceResponse.new(status: false, error: e)
      end

      # Use .find_or_create to generate/return memoized service-specific form submission record
      # @return [BGSFormSubmission] instance
      def find_or_create_form_submission
        @submission ||= BGS::Submission.find_or_create_by(form_id: '21-686C', saved_claim_id: saved_claim.id)
      end

      # Returns the memoized BGS submission record
      #
      # @return [BGS::Submission] The submission record
      def submission
        @submission ||= find_or_create_form_submission
      end

      # Generate a new form submission attempt record
      # Each retry gets its own attempt record for debugging
      # @return [LighthouseFormSubmissionAttempt, BGSFormSubmissionAttempt] instance
      def create_form_submission_attempt
        @submission_attempt ||= BGS::SubmissionAttempt.create(submission:)
      end

      # Returns the memoized BGS submission attempt record
      #
      # @return [BGS::SubmissionAttempt] The attempt record
      def submission_attempt
        @submission_attempt ||= create_form_submission_attempt
      end

      # Marks the submission attempt as successful
      #
      # Service-specific success logic - updates submission attempt record to success status.
      #
      # @return [Boolean, nil] Result of status update, or nil if attempt doesn't exist
      def mark_submission_succeeded
        submission_attempt&.success!
      end

      # Marks the submission attempt as failed with error details
      #
      # Service-specific failure logic - updates submission attempt record with
      # failure status and stores the exception details.
      #
      # @param exception [Exception] The exception that caused the failure
      # @return [Boolean, nil] Result of status update, or nil if attempt doesn't exist
      def mark_submission_attempt_failed(exception)
        submission_attempt&.fail!(error: exception)
      end

      # No-op for BGS submissions
      #
      # BGS::Submission has no status update, so this is a no-op.
      # This differs from other submission types, which may require status updates on failure.
      #
      # @param _exception [Exception] The exception that caused the failure (unused)
      # @return [nil]
      def mark_submission_failed(_exception) = nil

      # Determines if an error represents a permanent BGS failure
      #
      # Checks if the error message or its cause matches any of the BGS filtered errors
      # that should not be retried (invalid SSN, duplicate claim, etc.).
      #
      # @param error [Exception, nil] The error to check
      # @return [Boolean] true if error matches BGS permanent failure patterns, false if transient
      def permanent_failure?(error)
        return false if error.nil?

        BGS::Job::FILTERED_ERRORS.any? { |filtered| error.message.include?(filtered) || error.cause&.message&.include?(filtered) }
      end
    end
  end
end
