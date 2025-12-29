# frozen_string_literal: true

module DependentsBenefits
  module ClaimBehavior
    ##
    # Methods for checking claim submission status across different services
    #
    module SubmissionStatus
      extend ActiveSupport::Concern

      # Checks if the claim was successfully submitted by checking the status of submission attempts
      #
      # @todo Add checks for each submission type for claim
      # @return [Boolean] true if all submission attempts succeeded, false otherwise
      def submissions_succeeded?
        submitted_to_bgs? && submitted_to_claims_evidence_api?
      end

      # Checks if the claim was successfully submitted to BGS
      def submitted_to_bgs?
        submissions = BGS::Submission.where(saved_claim_id: id)
        submissions.exists? && submissions.all? { |submission| submission.latest_attempt&.status == 'submitted' }
      end

      # Checks if the claim was successfully submitted to Claims Evidence API
      def submitted_to_claims_evidence_api?
        submissions = ClaimsEvidenceApi::Submission.where(saved_claim_id: id)
        submissions.exists? && submissions.all? { |submission| submission.latest_attempt&.status == 'accepted' }
      end
    end
  end
end
