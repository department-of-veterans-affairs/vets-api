# frozen_string_literal: true

require 'burials/processing_office'

module Burials
  ##
  # Burial 21P-530EZ Active::Record
  # @see app/model/saved_claim
  #
  # todo: migrate encryption to Burials::SavedClaim, remove inheritance and encryption shim
  class SavedClaim < ::SavedClaim
    # We want to use the `Type` behavior but we want to override it with our custom type default scope behaviors.
    self.inheritance_column = :_type_disabled

    # We want to override the `Type` behaviors for backwards compatability
    default_scope -> { where(type: 'SavedClaim::Burial') }, all_queries: true

    ##
    # The KMS Encryption Context is preserved from the saved claim model namespace we migrated from
    # ***********************************************************************************
    # Note: This CAN NOT be removed as long as there are existing records of this type. *
    # ***********************************************************************************
    #
    def kms_encryption_context
      {
        model_name: 'SavedClaim::Burial',
        model_id: id
      }
    end

    # Burial Form ID
    FORM = Burials::FORM_ID

    ##
    # Associates uploaded attachments with the current saved claim
    #
    # @return [void]
    def process_attachments!
      refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
      files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
      files.find_each { |f| f.update(saved_claim_id: id) }
    end

    ##
    # Retrieves the regional office address based on the claimant's postal code
    #
    # @return [Array<String>]
    def regional_office
      Burials::ProcessingOffice.address_for(open_struct_form.claimantAddress.postalCode)
    end

    ##
    # Returns an array of attachment keys used in process_attachments!
    #
    # @return [Array<Symbol>]
    def attachment_keys
      %i[transportationReceipts deathCertificate militarySeparationDocuments additionalEvidence].freeze
    end

    ##
    # Provides a mapping from claim attachment keys (as used in claim models)
    # to in-progress form keys (as used in InProgressForm#form_data) for Burials
    def attachment_key_map
      {
        transportationReceipts: :transportation_receipts,
        deathCertificate: :death_certificate,
        militarySeparationDocuments: :military_separation_documents,
        additionalEvidence: :additional_evidence
      }.freeze
    end

    ##
    # Parse claimant's email address from the parsed_form.
    #
    # @return [String, nil]
    def email
      parsed_form['claimantEmail']
    end

    ##
    # Validates whether the form matches the expected VetsJsonSchema::JSON schema
    #
    # @return [void]
    def form_matches_schema
      return unless form_is_string

      JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[form_id], parsed_form).each do |v|
        errors.add(:form, v.to_s)
      end
    end

    ##
    # Returns the business line associated with this process
    #
    # @return [String]
    def business_line
      'NCA'
    end

    # the VBMS document type for _this_ claim type
    def document_type
      133
    end

    ##
    # Utility function to retrieve veteran first name from form
    #
    # @return [String]
    def veteran_first_name
      parsed_form.dig('veteranFullName', 'first')
    end

    ##
    # Utility function to retrieve veteran last name from form
    #
    # @return [String]
    def veteran_last_name
      parsed_form.dig('veteranFullName', 'last')
    end

    ##
    # Utility function to retrieve claimant first name from form
    #
    # @return [String]
    def claimant_first_name
      parsed_form.dig('claimantFullName', 'first')
    end

    ##
    # Returns an array of benefits claimed based on the parsed form
    #
    # @return [Array<String>]
    def benefits_claimed
      claimed = []
      claimed << 'Burial Allowance' if parsed_form['burialAllowance']
      claimed << 'Plot Allowance' if parsed_form['plotAllowance']
      claimed << 'Transportation' if parsed_form['transportation']
      claimed
    end

    ##
    # Generates a PDF from the saved claim data
    #
    # @param file_name [String, nil] Optional name for the output PDF file
    # @param fill_options [Hash] Additional options for PDF generation
    # @return [String] Path to the generated PDF file
    #
    def to_pdf(file_name = nil, fill_options = {})
      ::PdfFill::Filler.fill_form(self, file_name, fill_options)
    end

    ##
    # Class name for notification email
    # @return [Class]
    def send_email(email_type)
      Burials::NotificationEmail.new(id).deliver(email_type)
    end
  end
end
