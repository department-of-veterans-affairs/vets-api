# frozen_string_literal: true

require 'lighthouse/benefits_intake/submission_handler/saved_claim'
require 'vre/monitor'

module VRE
  module BenefitsIntake
    class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
      private

      def claim_class
        SavedClaim::VeteranReadinessEmploymentClaim
      end

      def monitor
        @monitor ||= VRE::Monitor.new
      end

    end
  end
end
