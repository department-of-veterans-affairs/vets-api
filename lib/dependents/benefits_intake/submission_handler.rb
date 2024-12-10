# frozen_string_literal: true

require 'lighthouse/benefits_intake/submission_handler/saved_claim'
require 'dependents/monitor'

module Dependents
  module BenefitsIntake
    # @see BenefitsIntake::SubmissionHandler::SavedClaim
    class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
      private

      # BenefitsIntake::SubmissionHandler::SavedClaim#claim_class
      def claim_class
        SavedClaim::DependencyClaim
      end

      # BenefitsIntake::SubmissionHandler::SavedClaim#monitor
      def monitor
        @monitor ||= Dependents::Monitor.new
      end
    end
  end
end
