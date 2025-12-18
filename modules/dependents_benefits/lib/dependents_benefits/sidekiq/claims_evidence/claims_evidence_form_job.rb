# frozen_string_literal: true

require 'dependents_benefits/service_response'
require 'dependents_benefits/sidekiq/dependent_submission_job'
require 'claims_evidence_api/uploader'

module DependentsBenefits
  # Background jobs for dependent benefits claim processing
  module Sidekiq
    # Submodule for Claims Evidence API-related submission jobs
    module ClaimsEvidence
      ##
      # Submission job for dependent benefits forms via Claims Evidence API
      #
      # Handles the submission of dependent benefits forms (674, 686c) to the Claims
      # Evidence API. Processes the claim PDF, validates it, and uploads to the
      # veteran's eFolder. Detects permanent VEFS errors for appropriate retry behavior.
      #
      # This is an abstract base class that requires subclasses to implement:
      # - {#submit_686c_form}
      # - {#submit_674_form}
      #
      # @abstract Subclasses must implement abstract methods
      # @see DependentSubmissionJob
      # @see ClaimsEvidenceApi::Submission
      # @see ClaimsEvidenceApi::SubmissionAttempt
      #
      class ClaimsEvidenceFormJob < DependentSubmissionJob
        ##
        # Submit all child claims to the Claims Evidence API
        #
        # @return [void]
        # @raise [DependentSubmissionError] if any claim submission fails
        def submit_claims_to_service
          child_claims.each do |claim|
            service_response = submit_claim_to_service(claim)
            raise DependentSubmissionError, service_response&.error unless service_response&.success?
          end

          DependentsBenefits::ServiceResponse.new(status: true)
        end

        ##
        # Submit a 686c form to the Claims Evidence API
        #
        # @param claim [SavedClaim] The 686c claim to submit
        # @return [void]
        def submit_686c_form(claim)
          submit_to_claims_evidence_api(claim)
        end

        ##
        # Submit a 674 form to the Claims Evidence API
        #
        # @param claim [SavedClaim] The 674 claim to submit
        # @return [void]
        def submit_674_form(claim)
          submit_to_claims_evidence_api(claim)
        end

        ##
        # Submit a claim to the Claims Evidence API
        #
        # Performs the following steps:
        # 1. Processes the claim PDF using Lighthouse submission helper
        # 2. Uploads the evidence via Claims Evidence API uploader
        #
        # @param claim [SavedClaim] The claim to submit
        # @return [void]
        def submit_to_claims_evidence_api(claim)
          file_path = lighthouse_submission(claim).process_pdf(
            claim.to_pdf(form_id: claim.form_id),
            claim.created_at,
            claim.form_id
          )

          claims_evidence_uploader(claim).upload_evidence(
            claim.id,
            file_path:,
            form_id: claim.form_id,
            doctype: claim.document_type
          )
        end

        ##
        # Finds or creates a Claims Evidence API submission record
        #
        # Uses find_or_create_by to generate or return a memoized service-specific
        # form submission record. The record is keyed by form_id and saved_claim_id.
        #
        # @param claim [SavedClaim] The claim to find or create a submission for
        # @return [ClaimsEvidenceApi::Submission] The submission record (memoized)
        def find_or_create_form_submission(claim)
          ClaimsEvidenceApi::Submission.find_or_create_by(form_id: claim.form_id, saved_claim_id: claim.id)
        end

        ##
        # Check if a submission has already succeeded
        #
        # @param submission [ClaimsEvidenceApi::Submission] The form submission record to check
        # @return [Boolean] true if submission has an accepted attempt
        def submission_previously_succeeded?(submission)
          submission&.submission_attempts&.exists?(status: 'accepted')
        end

        ##
        # Generates a new form submission attempt record
        #
        # Each retry gets its own attempt record for debugging and tracking purposes.
        # The attempt is associated with the parent submission record.
        #
        # @param submission [ClaimsEvidenceApi::Submission] The submission to create an attempt for
        # @return [ClaimsEvidenceApi::SubmissionAttempt] The newly created attempt record (memoized)
        def create_form_submission_attempt(submission)
          ClaimsEvidenceApi::SubmissionAttempt.create(submission:)
        end

        ##
        # Marks the submission attempt as successful
        #
        # Service-specific success logic - updates the submission attempt record to
        # accepted status. Called after successful Claims Evidence API submission.
        #
        # @param submission_attempt [ClaimsEvidenceApi::SubmissionAttempt] The attempt to mark as succeeded
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
        # Returns a Claims Evidence API uploader instance
        #
        # @param claim [SavedClaim] The claim containing folder identifier
        # @return [ClaimsEvidenceApi::Uploader] Uploader configured with claim's folder identifier
        def claims_evidence_uploader(claim)
          ClaimsEvidenceApi::Uploader.new(claim.folder_identifier)
        end

        ##
        # Returns a Lighthouse submission helper instance
        #
        # Used for PDF processing utilities (stamping, dating) rather than actual Lighthouse
        # submission. The Claims Evidence API is the submission destination.
        #
        # @param claim [SavedClaim] The claim to process
        # @return [DependentsBenefits::BenefitsIntake::LighthouseSubmission] Submission helper
        def lighthouse_submission(claim)
          DependentsBenefits::BenefitsIntake::LighthouseSubmission.new(claim, user_data)
        end
      end
    end
  end
end
