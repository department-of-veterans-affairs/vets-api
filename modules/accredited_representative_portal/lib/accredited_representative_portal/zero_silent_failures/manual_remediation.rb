# frozen_string_literal: true

require 'zero_silent_failures/manual_remediation/saved_claim'

module AccreditedRepresentativePortal
  module ZeroSilentFailures
    # @see ZeroSilentFailures::ManualRemediation::SavedClaim
    class ManualRemediation < ::ZeroSilentFailures::ManualRemediation::SavedClaim
      private

      # specify the claim class to be used
      def claim_class
        proper_form_id = claim.proper_form_id
        AccreditedRepresentativePortal::SavedClaim::BenefitsIntake.form_class_from_proper_form_id(proper_form_id)
      end

      # override - add additional stamps
      # @see ZeroSilentFailures::ManualRemediation::SavedClaim#stamps
      #
      # @param timestamp [String] the timestamp
      #
      # @return [Array<Hash>] an array containing stamp metadata
      def stamps(timestamp)
        base = super(timestamp)
        arp_stamps = [
          {
            text: 'Representative Submission via VA.gov',
            x: 400,
            y: 770,
            text_only: true,
            timestamp:
          }
        ]

        base + arp_stamps
      end

      ##
      # Generates metadata for the claim by merging the base metadata with ARP-related information.
      #
      # Override - Added additional metadata
      # @see ZeroSilentFailures::ManualRemediation::SavedClaim#generate_metadata
      #
      # @return [Hash]
      def generate_metadata
        base = super

        attempt = FormSubmissionAttempt
                  .joins(:form_submission)
                  .where(form_submissions: { saved_claim_id: claim.id })
                  .order(id: :asc)
                  .last

        arp = {
          lighthouseBenefitIntakeSubmissionUUID: attempt&.benefits_intake_uuid,
          lighthouseBenefitIntakeSubmissionDate: attempt&.created_at
        }

        base.merge(arp)
      end
    end
  end
end
