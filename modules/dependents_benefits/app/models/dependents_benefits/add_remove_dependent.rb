# frozen_string_literal: true

require 'dependents_benefits/claim_behavior'

module DependentsBenefits
  # DependentsBenefit 21-686c Active::Record
  # @see app/model/saved_claim
  class AddRemoveDependent < ::SavedClaim
    include DependentsBenefits::ClaimBehavior

    # DependentsBenefit Form ID
    FORM = DependentsBenefits::ADD_REMOVE_DEPENDENT

    # Returns the business line associated with this process
    #
    # @return [String]
    def business_line
      'CMP'
    end

    # the VBMS document type for _this_ claim type
    def document_type
      148
    end
  end
end
