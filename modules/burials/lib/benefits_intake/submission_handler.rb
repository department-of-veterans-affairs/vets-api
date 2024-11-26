# frozen_string_literal: true

require 'lighthouse/benefits_intake/submission_handler/saved_claim'
require 'va_notify/notification_email/burial'
require 'burials/monitor'

module Burials
  module BenefitsIntake
    class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
      private

      def claim_class
        SavedClaim::Burial
      end

      def monitor
        @monitor ||= Burials::Monitor.new
      end

      def notification_email
        @notification_email = Burials::NotificationEmail.new(claim)
      end
    end
  end
end
