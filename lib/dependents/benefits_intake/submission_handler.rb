# frozen_string_literal: true

require 'lighthouse/benefits_intake/submission_handler/saved_claim'
require 'dependents/monitor'

module Dependents
  module BenefitsIntake
    class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
      private

      def claim_class
        SavedClaim::DependencyClaim
      end

      def monitor
        @monitor ||= Dependents::Monitor.new
      end

    end
  end
end
