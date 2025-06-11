# frozen_string_literal: true

require 'lighthouse/benefits_intake/submission_handler/saved_claim'
require 'pensions/monitor'
require 'pensions/notification_email'

module Pensions
  module BenefitsIntake
    # @see BenefitsIntake::SubmissionHandler::SavedClaim
    class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
      def self.pending_attempts
        Lighthouse::SubmissionAttempt.joins(:submission).where(status: 'pending',
                                                               'lighthouse_submissions.form_id' => '21P-527EZ')
      end

      private

      # BenefitsIntake::SubmissionHandler::SavedClaim#claim_class
      def claim_class
        Pensions::SavedClaim
      end

      # BenefitsIntake::SubmissionHandler::SavedClaim#monitor
      def monitor
        @monitor ||= Pensions::Monitor.new
      end

      # BenefitsIntake::SubmissionHandler::SavedClaim#notification_email
      def notification_email
        @notification_email ||= Pensions::NotificationEmail.new(claim.id)
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
