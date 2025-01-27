# frozen_string_literal: true

require 'lighthouse/benefits_intake/submission_handler/saved_claim'
require 'pensions/monitor'
require 'pensions/notification_email'

module Pensions
  module BenefitsIntake
    # @see BenefitsIntake::SubmissionHandler::SavedClaim
    class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
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
        @notification_email = Pensions::NotificationEmail.new(claim.id)
      end
    end
  end
end
