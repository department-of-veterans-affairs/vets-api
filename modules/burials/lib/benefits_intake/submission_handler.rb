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
        SavedClaim::Burial
      end

      # BenefitsIntake::SubmissionHandler::SavedClaim#monitor
      def monitor
        @monitor ||= Burials::Monitor.new
      end

      # BenefitsIntake::SubmissionHandler::SavedClaim#notification_email
      def notification_email
        @notification_email = Burials::NotificationEmail.new(claim.id)
      end
    end
  end
end
