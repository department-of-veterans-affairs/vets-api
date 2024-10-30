# frozen_string_literal: true

require 'zero_silent_failures/manual_remediation/saved_claim'

module Burials
  module ZeroSilentFailures
    class ManualRemediation < ::ZeroSilentFailures::ManualRemediation::SavedClaim

      private

      def claim_class
        ::SavedClaim::Burial
      end

      def stamps(timestamp)
        base = super(timestamp)
        burials = [
          {
            text: 'FDC Reviewed - VA.gov Submission',
            x: 400,
            y: 770,
            text_only: true,
            timestamp:
          }
        ]

        if ['21P-530V2'].include?(claim.form_id)
          burials << {
            text: 'Application Submitted on va.gov',
            x: 425,
            y: 675,
            text_only: true, # passing as text only because we override how the date is stamped in this instance
            timestamp:,
            page_number: 5,
            size: 9,
            template: "lib/pdf_fill/forms/pdfs/#{claim.form_id}.pdf",
            multistamp: true
          }
        end

        base + burials
      end

      def generate_metadata
        base = super

        submission = FormSubmission.where(saved_claim_id: claim.id)&.order(id: :asc)&.last
        attempt = submission&.form_submission_attempts&.order(id: :asc)&.last
        burials = {
          lighthouseBenefitIntakeSubmissionUUID: attempt&.benefits_intake_uuid,
          lighthouseBenefitIntakeSubmissionDate: attempt&.created_at
        }

        base.merge(burials)
      end
    end
  end
end
