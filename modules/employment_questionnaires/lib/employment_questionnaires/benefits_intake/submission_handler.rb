# frozen_string_literal: true

require 'lighthouse/benefits_intake/submission_handler/saved_claim'
require 'employment_questionnaires/monitor'
require 'employment_questionnaires/notification_email'

module EmploymentQuestionnaires
  module BenefitsIntake
    # @see BenefitsIntake::SubmissionHandler::SavedClaim
    class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
      # Retrieves all pending Lighthouse::SubmissionAttempt records associated with submissions
      # where the form_id is '21P-8416'.
      #
      # @return [ActiveRecord::Relation] a relation containing pending submission attempts for form '21P-530EZ'
      def self.pending_attempts
        Lighthouse::SubmissionAttempt.joins(:submission)
                                     .where(status: 'pending',
                                            'lighthouse_submissions.form_id' => EmploymentQuestionnaires::FORM_ID)
      end

      private

      # BenefitsIntake::SubmissionHandler::SavedClaim#claim_class
      def claim_class
        EmploymentQuestionnaires::SavedClaim
      end

      # BenefitsIntake::SubmissionHandler::SavedClaim#monitor
      def monitor
        @monitor ||= EmploymentQuestionnaires::Monitor.new
      end

      # BenefitsIntake::SubmissionHandler::SavedClaim#notification_email
      def notification_email
        @notification_email ||= EmploymentQuestionnaires::NotificationEmail.new(claim.id)
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
