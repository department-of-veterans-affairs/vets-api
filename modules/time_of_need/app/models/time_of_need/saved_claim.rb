# frozen_string_literal: true

module TimeOfNeed
  ##
  # Time of Need 40-4962 SavedClaim
  #
  # Stores burial scheduling form data submitted through VA.gov.
  # Inherits encryption and schema validation from SavedClaim.
  #
  # @see app/models/saved_claim.rb
  #
  class SavedClaim < ::SavedClaim
    # Disable STI column so we can use our own type scoping
    self.inheritance_column = :_type_disabled

    # Scope to only TimeOfNeed claims
    default_scope -> { where(type: 'SavedClaim::TimeOfNeed') }, all_queries: true

    # Form ID constant required by SavedClaim
    FORM = TimeOfNeed::FORM_ID

    ##
    # KMS encryption context for this claim type
    #
    # @return [Hash]
    def kms_encryption_context
      {
        model_name: 'SavedClaim::TimeOfNeed',
        model_id: id
      }
    end

    ##
    # Associates uploaded attachments (supporting documents) with the claim
    #
    # @return [void]
    def process_attachments!
      refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
      files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
      files.find_each { |f| f.update(saved_claim_id: id) }
    end

    ##
    # Keys for file attachments in the form data
    #
    # @return [Array<Symbol>]
    def attachment_keys
      %i[attachments].freeze
    end

    ##
    # Parse applicant's email address from the parsed form
    #
    # @return [String, nil]
    def email
      parsed_form['applicantEmail']
    end
  end
end
