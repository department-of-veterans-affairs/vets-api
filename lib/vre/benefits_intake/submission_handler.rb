# frozen_string_literal: true

require 'lighthouse/benefits_intake/submission_handler/saved_claim'
require 'vre/monitor'

module VRE
  module BenefitsIntake
    # @see BenefitsIntake::SubmissionHandler::SavedClaim
    class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
      private

      # BenefitsIntake::SubmissionHandler::SavedClaim#claim_class
      def claim_class
        SavedClaim::VeteranReadinessEmploymentClaim
      end

      # BenefitsIntake::SubmissionHandler::SavedClaim#monitor
      def monitor
        @monitor ||= VRE::Monitor.new
      end
    end
  end
end
