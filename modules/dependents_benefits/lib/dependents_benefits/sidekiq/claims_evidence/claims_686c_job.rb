# frozen_string_literal: true

require 'dependents_benefits/monitor'
require 'dependents_benefits/service_response'
require 'dependents_benefits/sidekiq/dependent_submission_job'
require 'claims_evidence_api/uploader'

module DependentsBenefits
  module Sidekiq
    module ClaimsEvidence
      ##
      # Submission job for 686c claims via Claims Evidence API
      #
      # Handles the submission of 686c (Add/Remove Dependent) forms to the Claims
      # Evidence API. Processes the claim PDF, validates it, and uploads to the
      # veteran's eFolder. Detects permanent VEFS errors for appropriate retry behavior.
      #
      class Claims686cJob < DependentSubmissionJob
        ##
        # Service-specific submission logic for Claims Evidence API
        # @return [ServiceResponse] Must respond to success? and error methods
        def submit_to_service
          file_path = lighthouse_submission.process_pdf(
            saved_claim.to_pdf(form_id: ADD_REMOVE_DEPENDENT),
            saved_claim.created_at,
            ADD_REMOVE_DEPENDENT
          )

          claims_evidence_uploader.upload_evidence(
            saved_claim.id,
            file_path:,
            form_id: ADD_REMOVE_DEPENDENT,
            doctype: saved_claim.document_type
          )

          DependentsBenefits::ServiceResponse.new(status: true)
        rescue => e
          DependentsBenefits::ServiceResponse.new(status: false, error: e)
        end

        ##
        # Returns the error class for invalid 686c claims
        #
        # @return [Class] Invalid686cClaim error class
        def invalid_claim_error_class
          Invalid686cClaim
        end

        # Use .find_or_create to generate/return memoized service-specific form submission record
        # @return [LighthouseFormSubmission, BGSFormSubmission] instance
        def find_or_create_form_submission
          @submission ||= ClaimsEvidenceApi::Submission.find_or_create_by(
            form_id: ADD_REMOVE_DEPENDENT,
            saved_claim_id: saved_claim.id
          )
        end

        # Returns the memoized Claims Evidence API submission record
        #
        # @return [ClaimsEvidenceApi::Submission] The submission record
        def submission
          @submission ||= find_or_create_form_submission
        end

        # Generate a new form submission attempt record
        # Each retry gets its own attempt record for debugging
        # @return [ClaimsEvidenceApi::SubmissionAttempt] instance
        def create_form_submission_attempt
          @submission_attempt ||= ClaimsEvidenceApi::SubmissionAttempt.create(submission:)
        end

        # Returns the memoized Claims Evidence API submission attempt record
        #
        # @return [ClaimsEvidenceApi::SubmissionAttempt] The attempt record
        def submission_attempt
          @submission_attempt ||= create_form_submission_attempt
        end

        # Marks the submission attempt as accepted
        #
        # Service-specific success logic - updates submission attempt record to accepted status.
        #
        # @return [Boolean, nil] Result of status update, or nil if attempt doesn't exist
        def mark_submission_succeeded
          submission_attempt&.accepted!
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

        # No-op for Claims Evidence API submissions
        #
        # ClaimsEvidenceApi::Submission has no status update, so this is a no-op.
        # This differs from other submission types, which may require status updates on failure.
        #
        # @param _exception [Exception] The exception that caused the failure (unused)
        # @return [nil]
        def mark_submission_failed(_exception) = nil

        # Determines if an error represents a permanent VEFS failure
        #
        # Checks for Claims Evidence API VEFS errors and identifies specific error codes
        # that should not be retried (authentication, authorization, schema validation, etc.).
        #
        # @param error [Exception, nil] The error to check
        # @return [Boolean] true if error is a permanent VEFS failure, false if transient
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

        # Returns a memoized Claims Evidence API uploader instance
        #
        # @return [ClaimsEvidenceApi::Uploader] Uploader configured with claim's folder identifier
        def claims_evidence_uploader
          @ce_uploader ||= ClaimsEvidenceApi::Uploader.new(saved_claim.folder_identifier)
        end

        # Returns a memoized Lighthouse submission helper instance
        #
        # Used for PDF processing utilities (stamping, dating) rather than actual Lighthouse
        # submission. The Claims Evidence API is the submission destination.
        #
        # @return [DependentsBenefits::BenefitsIntake::LighthouseSubmission] Submission helper
        def lighthouse_submission
          @lighthouse_submission ||= 
            DependentsBenefits::BenefitsIntake::LighthouseSubmission.new(saved_claim, user_data)
        end
      end
    end
  end
end
