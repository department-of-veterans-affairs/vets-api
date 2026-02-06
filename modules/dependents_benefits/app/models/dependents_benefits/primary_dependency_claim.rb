# frozen_string_literal: true

require 'dependents_benefits/claim_behavior'

module DependentsBenefits
  ##
  # DependentsBenefit 686C-674 Active::Record
  # @see app/model/saved_claim
  #
  # @todo: migrate encryption to DependentsBenefits::PrimaryDependencyClaim, remove inheritance and encryption shim
  class PrimaryDependencyClaim < ::SavedClaim
    include DependentsBenefits::ClaimBehavior

    # We want to use the `Type` behavior but we want to override it with our custom type default scope behaviors.
    self.inheritance_column = :_type_disabled

    # We want to override the `Type` behaviors for backwards compatability
    default_scope -> { where(type: 'SavedClaim::DependencyClaim') }, all_queries: true

    ##
    # The KMS Encryption Context is preserved from the saved claim model namespace we migrated from
    # ***********************************************************************************
    # Note: This CAN NOT be removed as long as there are existing records of this type. *
    # ***********************************************************************************
    #
    def kms_encryption_context
      {
        model_name: 'SavedClaim::DependencyClaim',
        model_id: id
      }
    end

    # DependentsBenefit Form ID
    FORM = DependentsBenefits::FORM_ID
  end
end
