# frozen_string_literal: true

require 'bgsv2/form674'
require 'dependents_benefits/sidekiq/bgs/bgs_form_job'

module DependentsBenefits
  # Background jobs for dependent benefits claim processing
  module Sidekiq
    # Sidekiq modules for BGS interactions
    module BGS
      ##
      # Submission job for 674 claims via BGS
      #
      # Handles the submission of 674 (School Attendance Approval) forms to BGS (Benefits
      # Gateway Service). Normalizes claim data, validates the claim, and submits to
      # BGS using the BGSV2::Form674 service. Detects permanent BGS errors for
      # appropriate retry behavior.
      #
      class BGS674Job < BGSFormJob
        ##
        # Returns the error class for invalid 674 claims
        #
        # @return [Class] Invalid674Claim error class
        def invalid_claim_error_class
          Invalid674Claim
        end

        ##
        # Submits the 674 form data to BGS
        #
        # @param claim_data [Hash] Normalized claim data with names and addresses
        # @return [Object] BGS service response
        def submit_form(claim_data)
          BGSV2::Form674
            .new(generate_user_struct, saved_claim, { proc_id:, claim_type_end_product: })
            .submit(claim_data)
        end

        ##
        # Returns the form identifier for 674 submissions
        #
        # @return [String] Form ID string '21-674'
        def form_id
          SCHOOL_ATTENDANCE_APPROVAL
        end
      end
    end
  end
end
