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
    #
    def kms_encryption_context
      {
        model_name: 'SavedClaim::Burial',
        model_id: id
      }
    end

    # Burial Form ID
    FORM = '21P-530EZ'

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
    # Processes a PDF by applying a timestamp and renaming it for VBMS upload
    #
    # @param pdf_path [String]
    # @param timestamp [Time, nil]
    # @param form_id [String, nil]
    #
    # @return [String]
    def process_pdf(pdf_path, timestamp = nil, form_id = nil)
      processed_pdf = PDFUtilities::DatestampPdf.new(pdf_path).run(
        text: 'Application Submitted on va.gov',
        x: 400,
        y: 675,
        text_only: true, # passing as text only because we override how the date is stamped in this instance
        timestamp:,
        page_number: 6,
        template: "lib/pdf_fill/forms/pdfs/#{form_id}.pdf",
        multistamp: true
      )
      renamed_path = "tmp/pdfs/#{form_id}_#{id}_final.pdf"
      File.rename(processed_pdf, renamed_path) # rename for vbms upload
      renamed_path # return the renamed path
    end

    ##
    # Returns the business line associated with this process
    #
    # @return [String]
    def business_line
      'NCA'
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
    def claimaint_first_name
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
  end
end
