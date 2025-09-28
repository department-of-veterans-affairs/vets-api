# frozen_string_literal: true

require 'lighthouse/benefits_intake/submission_handler/saved_claim'
require 'survivors_benefits/monitor'
require 'survivors_benefits/notification_email'

module SurvivorsBenefits
  module BenefitsIntake
    # @see BenefitsIntake::SubmissionHandler::SavedClaim
    class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
      # Retrieves all pending Lighthouse::SubmissionAttempt records associated with submissions
      # where the form_id is '21P-534EZ'.
      #
      # @return [ActiveRecord::Relation] a relation containing pending submission attempts for form '21P-534EZ'
      def self.pending_attempts
        Lighthouse::SubmissionAttempt.joins(:submission)
                                     .where(status: 'pending',
                                            'lighthouse_submissions.form_id' => SurvivorsBenefits::FORM_ID)
      end

      private

      # BenefitsIntake::SubmissionHandler::SavedClaim#claim_class
      def claim_class
        SurvivorsBenefits::SavedClaim
      end

      # BenefitsIntake::SubmissionHandler::SavedClaim#monitor
      def monitor
        @monitor ||= SurvivorsBenefits::Monitor.new
      end

      # BenefitsIntake::SubmissionHandler::SavedClaim#notification_email
      def notification_email
        @notification_email ||= SurvivorsBenefits::NotificationEmail.new(claim.id)
      end

      # handle a failure result
      # inheriting class must assign @avoided before calling `super`
      def on_failure
        @avoided = notification_email.deliver(:error)
        super
      end

      # handle a success result
      def on_success
        notification_email.deliver(:received)
        super
      end

      # handle a stale result
      def on_stale
        true
      end
    end
  end
end
