# frozen_string_literal: true

require 'dependents_benefits/monitor'
require 'dependents_benefits/service_response'
require 'dependents_benefits/sidekiq/dependent_submission_job'
require 'claims_evidence_api/uploader'

module DependentsBenefits
  module Sidekiq
    class Claims686cJob < DependentSubmissionJob
      ##
      # Service-specific submission logic - BGS vs Lighthouse vs Fax
      # @return [ServiceResponse] Must respond to success? and error methods
      def submit_to_service
        saved_claim.add_veteran_info(user_data)

        raise Invalid686cClaim unless saved_claim.valid?(:run_686_form_jobs)

        form_id = DependentsBenefits::ADD_REMOVE_DEPENDENT
        lighthouse_submission = DependentsBenefits::BenefitsIntake::LighthouseSubmission.new(saved_claim, user_data)
        file_path = lighthouse_submission.process_pdf(
          saved_claim.to_pdf(form_id:),
          saved_claim.created_at, form_id
        )
        @monitor.track_event('info', "#{self.class} claims evidence upload of #{form_id} claim_id #{saved_claim.id}",
                             "#{STATS_KEY}.claims_evidence.upload", tags: ["form_id:#{form_id}"])

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

      # Use .find_or_create to generate/return memoized service-specific form submission record
      # @return [LighthouseFormSubmission, BGSFormSubmission] instance
      def find_or_create_form_submission
        @submission ||= ClaimsEvidenceApi::Submission.find_or_create_by(
          form_id: DependentsBenefits::ADD_REMOVE_DEPENDENT,
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

        BGS::Job::FILTERED_ERRORS.any? { |filtered| error.message.include?(filtered) || error.cause&.message&.include?(filtered) }
      end

      def claims_evidence_uploader
        @ce_uploader ||= ClaimsEvidenceApi::Uploader.new(folder_identifier)
      end
    end
  end
end
