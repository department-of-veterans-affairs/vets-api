# frozen_string_literal: true

require 'bgsv2/form686c'
require 'dependents_benefits/sidekiq/bgs/bgs_form_job'

module DependentsBenefits
  module Sidekiq
    module BGS
      ##
      # Submission job for 686c claims via BGS
      #
      # Handles the submission of 686c (Add/Remove Dependent) forms to BGS (Benefits
      # Gateway Service). Normalizes claim data, validates the claim, and submits to
      # BGS using the BGSV2::Form686c service. Detects permanent BGS errors for
      # appropriate retry behavior.
      #
      class BGS686cJob < BGSFormJob
        ##
        # Returns the error class for invalid 686c claims
        #
        # @return [Class] Invalid686cClaim error class
        def invalid_claim_error_class
          Invalid686cClaim
        end

        ##
        # Submits the 686c form data to BGS
        #
        # @param claim_data [Hash] Normalized claim data with names and addresses
        # @return [Object] BGS service response
        def submit_form(claim_data)
          BGSV2::Form686c
            .new(generate_user_struct, saved_claim, { proc_id:, claim_type_end_product: })
            .submit(claim_data)
        end

        ##
        # Returns the form identifier for 686c submissions
        #
        # @return [String] Form ID string '21-686C'
        def form_id
          ADD_REMOVE_DEPENDENT
        end
      end
    end
  end
end
