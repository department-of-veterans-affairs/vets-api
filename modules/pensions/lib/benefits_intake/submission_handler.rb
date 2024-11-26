# frozen_string_literal: true

require 'lighthouse/benefits_intake/submission_handler/saved_claim'
require 'pensions/monitor'
require 'pensions/notification_email'

module Pensions
  module BenefitsIntake
    class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
      private

      def claim_class
        Pensions::SavedClaim
      end

      def monitor
        @monitor ||= Pensions::Monitor.new
      end

      def notification_email
        @notification_email = Pensions::NotificationEmail.new(claim)
      end
    end
  end
end
