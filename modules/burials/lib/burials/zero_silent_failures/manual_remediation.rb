# frozen_string_literal: true

require 'zero_silent_failures/manual_remediation/saved_claim'

module Burials
  module ZeroSilentFailures
    # @see ZeroSilentFailures::ManualRemediation::SavedClaim
    class ManualRemediation < ::ZeroSilentFailures::ManualRemediation::SavedClaim
      private

      # specify the claim class to be used
      def claim_class
        Burials::SavedClaim
      end

      # override - add additional stamps
      # @see ZeroSilentFailures::ManualRemediation::SavedClaim#stamps
      #
      # @param timestamp [String] the timestamp
      #
      # @return [Array<Hash>] an array containing stamp metadata
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

      ##
      # Generates a submitted stamp annotation for a PDF form
      #
      # @param timestamp [String] the submission timestamp
      #
      # @return [Array<Hash>] an array containing stamp metadata
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
            template: Burials.pdf_path,
            multistamp: true
          }
        ]
      end

      ##
      # Generates metadata for the claim by merging the base metadata with burial-related information.
      #
      # Override - Added additional metadata
      # @see ZeroSilentFailures::ManualRemediation::SavedClaim#generate_metadata
      #
      # @return [Hash]
      def generate_metadata
        base = super

        submission = Lighthouse::Submission.where(saved_claim_id: claim.id)&.order(id: :asc)&.last
        attempt = submission&.submission_attempts&.order(id: :asc)&.last
        burials = {
          lighthouseBenefitIntakeSubmissionUUID: attempt&.benefits_intake_uuid,
          lighthouseBenefitIntakeSubmissionDate: attempt&.created_at
        }

        base.merge(burials)
      end
    end
  end
end
