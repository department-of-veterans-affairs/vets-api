# frozen_string_literal: true

require 'dependents_benefits/monitor'
require 'dependents_benefits/service_response'
require 'dependents_benefits/sidekiq/dependent_submission_job'
require 'bgs/job'
require 'bgsv2/form686c'

module DependentsBenefits
  module Sidekiq
    class BGS686cJob < DependentSubmissionJob
      ##
      # Service-specific submission logic - BGS vs Lighthouse vs Fax
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
      # @return [LighthouseFormSubmission, BGSFormSubmission] instance
      def find_or_create_form_submission
        @submission ||= BGS::Submission.find_or_create_by(form_id: '21-686C', saved_claim_id: saved_claim.id)
      end

      def submission
        @submission ||= find_or_create_form_submission
      end

      # Generate a new form submission attempt record
      # Each retry gets its own attempt record for debugging
      # @return [LighthouseFormSubmissionAttempt, BGSFormSubmissionAttempt] instance
      def create_form_submission_attempt
        @submission_attempt ||= BGS::SubmissionAttempt.create(submission:)
      end

      def submission_attempt
        @submission_attempt ||= create_form_submission_attempt
      end

      # Service-specific success logic
      # Update submission attempt and form submission records
      def mark_submission_succeeded
        submission_attempt&.success!
      end

      # Service-specific failure logic
      # Update submission attempt record only with failure and error details
      def mark_submission_attempt_failed(exception)
        submission_attempt&.fail!(error: exception)
      end

      # Service-specific failure logic for permanent failures
      # Update form submission record to failed
      def mark_submission_failed(exception)
        submission&.fail!(error: exception)
      end

      def permanent_failure?(error)
        return false if error.nil?

        BGS::Job::FILTERED_ERRORS.any? { |filtered| error.message.include?(filtered) || error.cause&.message&.include?(filtered) }
      end
    end
  end
end
