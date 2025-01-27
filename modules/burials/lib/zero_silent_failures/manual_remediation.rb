# frozen_string_literal: true

require 'zero_silent_failures/manual_remediation/saved_claim'

module Burials
  module ZeroSilentFailures
    # @see ZeroSilentFailures::ManualRemediation::SavedClaim
    class ManualRemediation < ::ZeroSilentFailures::ManualRemediation::SavedClaim
      private

      # specify the claim class to be used
      def claim_class
        ::SavedClaim::Burial
      end

      # override - add additional stamps
      # @see ZeroSilentFailures::ManualRemediation::SavedClaim#stamps
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

        burials += submitted_stamp(timestamp)

        base + burials
      end

      def submitted_stamp(timestamp)
        [
          {
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
        ]
      end

      # override - add additional metadata
      # @see ZeroSilentFailures::ManualRemediation::SavedClaim#generate_metadata
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
