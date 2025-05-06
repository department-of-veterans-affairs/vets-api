# frozen_string_literal: true

require 'lighthouse/benefits_intake/submission_handler/saved_claim'
require 'burials/monitor'
require 'burials/notification_email'

module Burials
  module BenefitsIntake
    # @see BenefitsIntake::SubmissionHandler::SavedClaim
    class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
      private

      # BenefitsIntake::SubmissionHandler::SavedClaim#claim_class
      def claim_class
        Burials::SavedClaim
      end

      # BenefitsIntake::SubmissionHandler::SavedClaim#monitor
      def monitor
        @monitor ||= Burials::Monitor.new
      end

      # BenefitsIntake::SubmissionHandler::SavedClaim#notification_email
      def notification_email
        @notification_email ||= Burials::NotificationEmail.new(claim.id)
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
