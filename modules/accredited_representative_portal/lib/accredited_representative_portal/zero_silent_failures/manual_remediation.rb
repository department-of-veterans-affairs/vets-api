# frozen_string_literal: true

require 'zero_silent_failures/manual_remediation/saved_claim'

module AccreditedRepresentativePortal
  module ZeroSilentFailures
    # @see ZeroSilentFailures::ManualRemediation::SavedClaim
    class ManualRemediation < ::ZeroSilentFailures::ManualRemediation::SavedClaim
      private

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
        attempt = claim.latest_submission_attempt
        form = claim.parsed_form

        {
          claimId: claim.id,
          docType: claim.form_id,
          formStartDate: claim.created_at,
          claimSubmissionDate: claim.created_at,
          claimConfirmation: attempt.benefits_intake_uuid,
          fileNumber: form['dependent']['ssn'] || form['veteran']['ssn'],
          businessLine: claim.business_line,
          lighthouseBenefitIntakeSubmissionUUID: attempt&.benefits_intake_uuid,
          lighthouseBenefitIntakeSubmissionDate: attempt&.created_at,
          veteranFirstName: form['veteran']['name']['first'],
          veteranLastName: form['veteran']['name']['last'],
          zipCode: form['veteran']['postalCode']
        }
      end
    end
  end
end
