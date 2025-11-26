# frozen_string_literal: true

require 'dependents_benefits/service_response'
require 'dependents_benefits/sidekiq/dependent_submission_job'
require 'bgs/job'

module DependentsBenefits
  # Background jobs for dependent benefits claim processing
  module Sidekiq
    ##
    # Submission job for dependent benefits forms via BGS
    #
    # Handles the submission of dependent benefits forms (674, 686c) to BGS (Benefits
    # Gateway Service). Normalizes claim data, validates the claim, and submits to
    # BGS using the appropriate BGSV2 service. Detects permanent BGS errors for
    # appropriate retry behavior.
    #
    # This is an abstract base class that requires subclasses to implement:
    # - {#invalid_claim_error_class}
    # - {#submit_form}
    # - {#form_id}
    #
    # @abstract Subclasses must implement abstract methods
    # @see DependentSubmissionJob
    # @see BGS::Submission
    # @see BGS::SubmissionAttempt
    #
    class BGSFormJob < DependentSubmissionJob
      ##
      # Submits the normalized claim data to BGS
      #
      # @abstract Subclasses must implement this method
      # @param claim_data [Hash] Normalized claim data with names and addresses
      # @return [Object] BGS service response
      # @raise [NotImplementedError] if not implemented by subclass
      def submit_form(claim_data)
        raise NotImplementedError, 'Subclasses must implement submit_form method'
      end

      ##
      # Returns the form identifier for this submission type
      #
      # @abstract Subclasses must implement this method
      # @return [String] Form ID (e.g., '21-686C', '21-674')
      # @raise [NotImplementedError] if not implemented by subclass
      def form_id
        raise NotImplementedError, 'Subclasses must implement form_id method'
      end

      ##
      # Service-specific submission logic for BGS
      #
      # Performs the following steps:
      # 1. Normalizes names and addresses in the claim data
      # 2. Submits the form via the subclass-implemented {#submit_form} method
      #
      # @return [DependentsBenefits::ServiceResponse] Response object with status and error
      # @raise [StandardError] via invalid_claim_error_class if claim validation fails
      def submit_to_service
        claim_data = BGS::Job.new.normalize_names_and_addresses!(saved_claim.parsed_form)

        submit_form(claim_data)

        DependentsBenefits::ServiceResponse.new(status: true)
      rescue => e
        DependentsBenefits::ServiceResponse.new(status: false, error: e)
      end

      ##
      # Finds or creates a BGS form submission record
      #
      # Uses find_or_create_by to generate or return a memoized service-specific
      # form submission record. The record is keyed by form_id and saved_claim_id.
      #
      # @return [BGS::Submission] The submission record (memoized)
      def find_or_create_form_submission
        @submission ||= BGS::Submission.find_or_create_by(form_id:, saved_claim_id: saved_claim.id)
      end

      ##
      # Returns the memoized BGS submission record
      #
      # Lazily initializes the submission record via {#find_or_create_form_submission}
      # if not already loaded.
      #
      # @return [BGS::Submission] The submission record
      def submission
        @submission ||= find_or_create_form_submission
      end

      ##
      # Generates a new form submission attempt record
      #
      # Each retry gets its own attempt record for debugging and tracking purposes.
      # The attempt is associated with the parent submission record.
      #
      # @return [BGS::SubmissionAttempt] The newly created attempt record (memoized)
      def create_form_submission_attempt
        @submission_attempt ||= BGS::SubmissionAttempt.create(submission:)
      end

      ##
      # Returns the memoized BGS submission attempt record
      #
      # Lazily initializes the attempt record via {#create_form_submission_attempt}
      # if not already loaded.
      #
      # @return [BGS::SubmissionAttempt] The attempt record
      def submission_attempt
        @submission_attempt ||= create_form_submission_attempt
      end

      ##
      # Marks the submission attempt as successful
      #
      # Service-specific success logic - updates the submission attempt record to
      # success status. Called after successful BGS submission.
      #
      # @return [Boolean, nil] Result of status update, or nil if attempt doesn't exist
      def mark_submission_succeeded
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
      def mark_submission_attempt_failed(exception)
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

        BGS::Job::FILTERED_ERRORS.any? { |filtered| error.message.include?(filtered) || error.cause&.message&.include?(filtered) }
      end
    end
  end
end
