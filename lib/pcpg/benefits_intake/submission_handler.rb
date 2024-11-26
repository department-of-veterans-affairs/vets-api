# frozen_string_literal: true

require 'lighthouse/benefits_intake/submission_handler/saved_claim'
require 'pcpg/monitor'

module PCPG
  module BenefitsIntake
    class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
      private

      def claim_class
        SavedClaim::EducationCareerCounselingClaim
      end

      def monitor
        @monitor ||= PCPG::Monitor.new
      end
    end
  end
end
