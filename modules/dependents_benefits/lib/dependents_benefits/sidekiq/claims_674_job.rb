# frozen_string_literal: true

require 'dependents_benefits/monitor'
require 'dependents_benefits/service_response'
require 'dependents_benefits/sidekiq/dependent_submission_job'
require 'claims_evidence_api/uploader'

module DependentsBenefits
  module Sidekiq
    class Claims674Job < DependentSubmissionJob
      class Invalid674Claim < StandardError; end
      FORM_ID = DependentsBenefits::SCHOOL_ATTENDANCE_APPROVAL.freeze
      ##
      # Service-specific submission logic - BGS vs Lighthouse vs Fax
      # @return [ServiceResponse] Must respond to success? and error methods
      def submit_to_service
        saved_claim.add_veteran_info(user_data)

        raise Invalid674Claim unless saved_claim.valid?(:run_686_form_jobs)

        file_path = lighthouse_submission.process_pdf(
          saved_claim.to_pdf(form_id: FORM_ID),
          saved_claim.created_at,
          FORM_ID
        )

        claims_evidence_uploader.upload_evidence(
          saved_claim.id,
          file_path:,
          form_id: FORM_ID,
          doctype: saved_claim.document_type
        )

        DependentsBenefits::ServiceResponse.new(status: true)
      rescue => e
        DependentsBenefits::ServiceResponse.new(status: false, error: e)
      end

      # Use .find_or_create to generate/return memoized service-specific form submission record
      # @return [LighthouseFormSubmission, BGSFormSubmission] instance
      def find_or_create_form_submission
        @submission ||= ClaimsEvidenceApi::Submission.find_or_create_by(
          form_id: FORM_ID,
          saved_claim_id: saved_claim.id
        )
      end

      def submission
        @submission ||= find_or_create_form_submission
      end

      # Generate a new form submission attempt record
      # Each retry gets its own attempt record for debugging
      # @return [LighthouseFormSubmissionAttempt, BGSFormSubmissionAttempt] instance
      def create_form_submission_attempt
        @submission_attempt ||= ClaimsEvidenceApi::SubmissionAttempt.create(submission:)
      end

      def submission_attempt
        @submission_attempt ||= create_form_submission_attempt
      end

      # Service-specific success logic
      # Update submission attempt and form submission records
      def mark_submission_succeeded
        submission_attempt&.accepted!
      end

      # Service-specific failure logic
      # Update submission attempt record only with failure and error details
      def mark_submission_attempt_failed(exception)
        submission_attempt&.fail!(error: exception)
      end

      #
      # BGS::Submission has no status update, so no-op here
      # This differs from other submission types, which may require status updates on failure.
      def mark_submission_failed(_exception) = nil

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

      def claims_evidence_uploader
        @ce_uploader ||= ClaimsEvidenceApi::Uploader.new(saved_claim.folder_identifier)
      end

      def lighthouse_submission
        @lighthouse_submission ||= DependentsBenefits::BenefitsIntake::LighthouseSubmission.new(saved_claim,
                                                                                                user_data)
      end
    end
  end
end
