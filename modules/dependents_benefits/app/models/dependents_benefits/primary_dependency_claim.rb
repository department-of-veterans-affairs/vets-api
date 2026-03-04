# frozen_string_literal: true

require 'dependents_benefits/claim_behavior'
require 'dependents_benefits/claim_behavior/vbms_information'

module DependentsBenefits
  ##
  # DependentsBenefit 686C-674 Active::Record
  # @see app/model/saved_claim
  #
  # @todo: migrate encryption to DependentsBenefits::PrimaryDependencyClaim, remove inheritance and encryption shim
  class PrimaryDependencyClaim < ::SavedClaim
    include DependentsBenefits::ClaimBehavior
    include DependentsBenefits::ClaimBehavior::VBMSInformation

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

    # Run after a claim is saved, this processes any files/supporting documents that are present
    def process_attachments!
      child_documents = parsed_form.dig('dependents_application', 'child_supporting_documents')
      spouse_documents = parsed_form.dig('dependents_application', 'spouse_supporting_documents')
      # add the two arrays together but also account for nil arrays
      supporting_documents = [child_documents, spouse_documents].compact.reduce([], :|)
      if supporting_documents.present?
        files = PersistentAttachment.where(guid: supporting_documents.pluck('confirmation_code'))
        files.find_each { |f| f.update(saved_claim_id: id) }
      end
    end

  end
end
