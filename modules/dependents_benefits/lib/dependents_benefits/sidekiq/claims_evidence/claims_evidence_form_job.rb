# frozen_string_literal: true

require 'dependents_benefits/monitor'
require 'dependents_benefits/service_response'
require 'dependents_benefits/sidekiq/dependent_submission_job'
require 'claims_evidence_api/uploader'

module DependentsBenefits
  # Background jobs for dependent benefits claim processing
  module Sidekiq
    module ClaimsEvidence
      ##
      # Submission job for dependent benefits forms via Claims Evidence API
      #
      # Handles the submission of dependent benefits forms (674, 686c) to the Claims
      # Evidence API. Processes the claim PDF, validates it, and uploads to the
      # veteran's eFolder. Detects permanent VEFS errors for appropriate retry behavior.
      #
      # This is an abstract base class that requires subclasses to implement:
      # - {#invalid_claim_error_class}
      # - {#form_id}
      #
      # @abstract Subclasses must implement abstract methods
      # @see DependentSubmissionJob
      # @see ClaimsEvidenceApi::Submission
      # @see ClaimsEvidenceApi::SubmissionAttempt
      #
      class ClaimsEvidenceFormJob < DependentSubmissionJob
        ##
        # Returns the form identifier for this submission type
        #
        # @abstract Subclasses must implement this method
        # @return [String] Form ID (e.g., 'ADD_REMOVE_DEPENDENT', 'SCHOOL_ATTENDANCE_APPROVAL')
        # @raise [NotImplementedError] if not implemented by subclass
        def form_id
          raise NotImplementedError, 'Subclasses must implement form_id method'
        end

        ##
        # Service-specific submission logic for Claims Evidence API
        #
        # Performs the following steps:
        # 1. Processes the claim PDF using Lighthouse submission helper
        # 2. Uploads the evidence via Claims Evidence API uploader
        #
        # @return [DependentsBenefits::ServiceResponse] Response object with status and error
        def submit_to_service
          file_path = lighthouse_submission.process_pdf(
            saved_claim.to_pdf(form_id:),
            saved_claim.created_at,
            form_id
          )

          claims_evidence_uploader.upload_evidence(
            saved_claim.id,
            file_path:,
            form_id:,
            doctype: saved_claim.document_type
          )

          DependentsBenefits::ServiceResponse.new(status: true)
        rescue => e
          DependentsBenefits::ServiceResponse.new(status: false, error: e)
        end

        ##
        # Finds or creates a Claims Evidence API submission record
        #
        # Uses find_or_create_by to generate or return a memoized service-specific
        # form submission record. The record is keyed by form_id and saved_claim_id.
        #
        # @return [ClaimsEvidenceApi::Submission] The submission record (memoized)
        def find_or_create_form_submission
          @submission ||= ClaimsEvidenceApi::Submission.find_or_create_by(
            form_id:,
            saved_claim_id: saved_claim.id
          )
        end

        ##
        # Returns the memoized Claims Evidence API submission record
        #
        # Lazily initializes the submission record via {#find_or_create_form_submission}
        # if not already loaded.
        #
        # @return [ClaimsEvidenceApi::Submission] The submission record
        def submission
          @submission ||= find_or_create_form_submission
        end

        ##
        # Generates a new form submission attempt record
        #
        # Each retry gets its own attempt record for debugging and tracking purposes.
        # The attempt is associated with the parent submission record.
        #
        # @return [ClaimsEvidenceApi::SubmissionAttempt] The newly created attempt record (memoized)
        def create_form_submission_attempt
          @submission_attempt ||= ClaimsEvidenceApi::SubmissionAttempt.create(submission:)
        end

        ##
        # Returns the memoized Claims Evidence API submission attempt record
        #
        # Lazily initializes the attempt record via {#create_form_submission_attempt}
        # if not already loaded.
        #
        # @return [ClaimsEvidenceApi::SubmissionAttempt] The attempt record
        def submission_attempt
          @submission_attempt ||= create_form_submission_attempt
        end

        ##
        # Marks the submission attempt as successful
        #
        # Service-specific success logic - updates the submission attempt record to
        # accepted status. Called after successful Claims Evidence API submission.
        #
        # @return [Boolean, nil] Result of status update, or nil if attempt doesn't exist
        def mark_submission_succeeded
          submission_attempt&.accepted!
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
        # No-op for Claims Evidence API submissions
        #
        # ClaimsEvidenceApi::Submission records do not have a status field, so this method is a no-op.
        # This differs from other submission types (e.g., EVSS), which may require
        # status updates on the submission record itself when a failure occurs.
        #
        # @param _exception [Exception] The exception that caused the failure (unused)
        # @return [nil]
        def mark_submission_failed(_exception)
          nil
        end

        ##
        # Determines if an error represents a permanent VEFS failure
        #
        # Checks for Claims Evidence API VEFS errors and identifies specific error codes
        # that should not be retried (authentication, authorization, schema validation, etc.).
        # Permanent failures will not trigger job retries, while transient errors will.
        #
        # @param error [Exception, nil] The error to check
        # @return [Boolean] true if error represents a permanent VEFS failure, false if transient or nil
        # @see ClaimsEvidenceApi::Exceptions::VefsError
        def permanent_failure?(error)
          return false if error.nil?

          # Check for Claims Evidence API permanent failures
          if error.is_a?(ClaimsEvidenceApi::Exceptions::VefsError) || error.cause.is_a?(ClaimsEvidenceApi::Exceptions::VefsError)
            vefs_error = error.is_a?(ClaimsEvidenceApi::Exceptions::VefsError) ? error : error.cause

            # These are considered permanent failures that should not be retried
            permanent_error_codes = [
              ClaimsEvidenceApi::Exceptions::VefsError::DISABLED_IDENTIFIER,
              ClaimsEvidenceApi::Exceptions::VefsError::INVALID_JWT,
              ClaimsEvidenceApi::Exceptions::VefsError::INVALID_X_EFOLDER_URI,
              ClaimsEvidenceApi::Exceptions::VefsError::UNAUTHORIZED,
              ClaimsEvidenceApi::Exceptions::VefsError::UNABLE_TO_RETRIEVE_VETERAN,
              ClaimsEvidenceApi::Exceptions::VefsError::UNABLE_TO_RETRIEVE_PERSON,
              ClaimsEvidenceApi::Exceptions::VefsError::DOES_NOT_CONFORM_TO_SCHEMA,
              ClaimsEvidenceApi::Exceptions::VefsError::INVALID_REQUEST
            ]

            return permanent_error_codes.any? { |code| vefs_error.message.include?(code) }
          end

          false
        end

        private

        ##
        # Returns a memoized Claims Evidence API uploader instance
        #
        # @return [ClaimsEvidenceApi::Uploader] Uploader configured with claim's folder identifier
        def claims_evidence_uploader
          @ce_uploader ||= ClaimsEvidenceApi::Uploader.new(saved_claim.folder_identifier)
        end

        ##
        # Returns a memoized Lighthouse submission helper instance
        #
        # Used for PDF processing utilities (stamping, dating) rather than actual Lighthouse
        # submission. The Claims Evidence API is the submission destination.
        #
        # @return [DependentsBenefits::BenefitsIntake::LighthouseSubmission] Submission helper
        def lighthouse_submission
          @lighthouse_submission ||= DependentsBenefits::BenefitsIntake::LighthouseSubmission.new(saved_claim,
                                                                                                  user_data)
        end
      end
    end
  end
end
