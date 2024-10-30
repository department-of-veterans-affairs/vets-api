# frozen_string_literal: true

require 'zero_silent_failures/manual_remediation/saved_claim'

module Pensions
  module ZeroSilentFailures
    class ManualRemediation < ::ZeroSilentFailures::ManualRemediation::SavedClaim

      private

      def claim_class
        ::Pensions::SavedClaim
      end

      def stamps(timestamp)
        base = super(timestamp)
        pensions = [
          {
            text: 'FDC Reviewed - VA.gov Submission',
            x: 429,
            y: 770,
            text_only: true,
            timestamp:
          }
        ]

        base + pensions
      end

      def generate_metadata
        base = super

        submission = FormSubmission.where(saved_claim_id: claim.id)&.order(id: :asc)&.last
        attempt = submission&.form_submission_attempts&.order(id: :asc)&.last
        pensions = {
          lighthouseBenefitIntakeSubmissionUUID: attempt&.benefits_intake_uuid,
          lighthouseBenefitIntakeSubmissionDate: attempt&.created_at
        }

        base.merge(pensions)
      end
    end
  end
end
