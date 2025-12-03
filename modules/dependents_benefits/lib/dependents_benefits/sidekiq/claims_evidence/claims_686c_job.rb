# frozen_string_literal: true

require 'dependents_benefits/sidekiq/claims_evidence/claims_evidence_form_job'

module DependentsBenefits
  module Sidekiq
    module ClaimsEvidence
      ##
      # Submission job for 686c claims via Claims Evidence API
      #
      # Handles the submission of 686c (Add/Remove Dependent) forms to the Claims
      # Evidence API. Processes the claim PDF, validates it, and uploads to the
      # veteran's eFolder. Detects permanent VEFS errors for appropriate retry behavior.
      #
      class Claims686cJob < ClaimsEvidenceFormJob
        ##
        # Returns the error class for invalid 686c claims
        #
        # @return [Class] Invalid686cClaim error class
        def invalid_claim_error_class
          Invalid686cClaim
        end

        ##
        # Returns the form identifier for 686c submissions
        #
        # @return [String] Form ID constant ADD_REMOVE_DEPENDENT
        def form_id
          ADD_REMOVE_DEPENDENT
        end
      end
    end
  end
end
