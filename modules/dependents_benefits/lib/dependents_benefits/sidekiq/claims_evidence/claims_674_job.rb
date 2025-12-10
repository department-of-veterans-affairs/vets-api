# frozen_string_literal: true

require 'dependents_benefits/sidekiq/claims_evidence/claims_evidence_form_job'

module DependentsBenefits
  # Background jobs for dependent benefits claim processing
  module Sidekiq
    # Sidekiq modules for ClaimsEvidence interactions
    module ClaimsEvidence
      ##
      # Submission job for 674 claims via Claims Evidence API
      #
      # Handles the submission of 674 (School Attendance Approval) forms to the Claims
      # Evidence API. Processes the claim PDF, validates it, and uploads to the
      # veteran's eFolder. Detects permanent VEFS errors for appropriate retry behavior.
      #
      class Claims674Job < ClaimsEvidenceFormJob
        ##
        # Returns the error class for invalid 674 claims
        #
        # @return [Class] Invalid674Claim error class
        def invalid_claim_error_class
          Invalid674Claim
        end

        ##
        # Returns the form identifier for 674 submissions
        #
        # @return [String] Form ID constant SCHOOL_ATTENDANCE_APPROVAL
        def form_id
          SCHOOL_ATTENDANCE_APPROVAL
        end
      end
    end
  end
end
