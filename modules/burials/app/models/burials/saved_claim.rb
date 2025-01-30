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

    FORM = '21P-530EZ'

    def process_attachments!
      refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
      files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
      files.find_each { |f| f.update(saved_claim_id: id) }
    end

    def regional_office
      Burials::ProcessingOffice.address_for(open_struct_form.claimantAddress.postalCode)
    end

    def attachment_keys
      %i[transportationReceipts deathCertificate militarySeparationDocuments additionalEvidence].freeze
    end

    def email
      parsed_form['claimantEmail']
    end

    def form_matches_schema
      return unless form_is_string

      JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[form_id], parsed_form).each do |v|
        errors.add(:form, v.to_s)
      end
    end

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

    def business_line
      'NCA'
    end

    ##
    # utility function to retrieve claimant first name from form
    #
    # @return [String] the claimant first name
    #
    def veteran_first_name
      parsed_form.dig('veteranFullName', 'first')
    end

    def veteran_last_name
      parsed_form.dig('veteranFullName', 'last')
    end

    def claimaint_first_name
      parsed_form.dig('claimantFullName', 'first')
    end

    def benefits_claimed
      claimed = []
      claimed << 'Burial Allowance' if parsed_form['burialAllowance']
      claimed << 'Plot Allowance' if parsed_form['plotAllowance']
      claimed << 'Transportation' if parsed_form['transportation']
      claimed
    end
  end
end
