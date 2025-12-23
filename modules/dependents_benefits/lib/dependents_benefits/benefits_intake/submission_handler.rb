# frozen_string_literal: true

require 'lighthouse/benefits_intake/submission_handler/saved_claim'
require 'dependents_benefits/monitor'
require 'dependents_benefits/notification_email'

module DependentsBenefits
  module BenefitsIntake
    # @see BenefitsIntake::SubmissionHandler::SavedClaim
    class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
      # Retrieves all pending Lighthouse::SubmissionAttempt records associated with submissions
      # where the form_id is '686C-674-V2'.
      #
      # @return [ActiveRecord::Relation] a relation containing pending submission attempts for form '686C-674-V2'
      def self.pending_attempts
        Lighthouse::SubmissionAttempt.joins(:submission).where(status: 'pending',
                                                               'lighthouse_submissions.form_id' => DependentsBenefits::FORM_ID_V2)
      end

      private

      # BenefitsIntake::SubmissionHandler::SavedClaim#claim_class
      def claim_class
        DependentsBenefits::PrimaryDependencyClaim
      end

      # BenefitsIntake::SubmissionHandler::SavedClaim#monitor
      def monitor
        @monitor ||= DependentsBenefits::Monitor.new
      end

      # BenefitsIntake::SubmissionHandler::SavedClaim#notification_email
      def notification_email
        @notification_email ||= Dependents::NotificationEmail.new(claim.id)
      end

      # handle a failure result
      # inheriting class must assign @avoided before calling `super`
      def on_failure
        @avoided = notification_email.send_error_notification
        super
      end

      # handle a success result
      def on_success
        notification_email.send_received_notification
        super
      end

      # handle a stale result
      def on_stale
        true
      end
    end
  end
end
