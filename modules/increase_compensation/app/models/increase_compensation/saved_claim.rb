# frozen_string_literal: true

require 'increase_compensation/benefits_intake/submit_claim_job'
require 'increase_compensation/pdf_stamper'
require 'pdf_fill/filler'

module IncreaseCompensation
  ##
  # IncreaseCompensation 21-8940v1 Active::Record
  # @see app/model/saved_claim
  #
  class SavedClaim < ::SavedClaim
    # Increase Compensation Form ID
    FORM = IncreaseCompensation::FORM_ID

    # the predefined regional office address
    #
    # @return [Array<String>] the address lines of the regional office
    def regional_office
      [
        'Department of Veterans Affairs',
        'Evidence Intake Center',
        'P.O. Box 4444',
        'Janesville, Wisconsin 53547-4444'
      ]
    end

    ##
    # Returns the business line associated with this process
    #
    # @return [String]
    def business_line
      'CMP'
    end

    # the VBMS document type for _this_ claim type
    def document_type
      'L149'
    end

    # Utility function to retrieve claimant email from form
    #
    # @return [String] the claimant email
    def email
      parsed_form['email'] || parsed_form['emailAddress']
    end

    # Utility function to retrieve veteran first name from form
    #
    # @return [String]
    def veteran_first_name
      parsed_form.dig('veteranFullName', 'first')
    end

    # Utility function to retrieve veteran last name from form
    #
    # @return [String]
    def veteran_last_name
      parsed_form.dig('veteranFullName', 'last')
    end

    ##
    # claim attachment list
    #
    # @see PersistentAttachment
    #
    # @return [Array<String>] list of attachments
    #
    def attachment_keys
      [:files].freeze
    end

    # Run after a claim is saved, this processes any files and workflows that are present
    # and sends them to our internal partners for processing.
    # Only removed Sidekiq call from super
    def process_attachments!
      refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
      files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
      files.find_each { |f| f.update(saved_claim_id: id) }

      # Lighthouse::SubmitBenefitsIntakeClaim.perform_async(id)
    end

    ##
    # Generates a PDF from the saved claim data
    #
    # @param file_name [String, nil] Optional name for the output PDF file
    # @param fill_options [Hash] Additional options for PDF generation
    # @return [String] Path to the generated PDF file
    #
    def to_pdf(file_name = nil, fill_options = {})
      pdf_path = ::PdfFill::Filler.fill_form(self, file_name, fill_options)
      # test fails because form is nil
      if form && pdf_path.present?
        signed_path = IncreaseCompensation::PdfStamper.stamp_signature(pdf_path, parsed_form)
        Rails.logger.info('IncreaseCompensation::ToPdf Stamped', { signed_path:, pdf_path: })

        # stamp_signature will return the original file_path if signature is blank OR on failure
        if pdf_path != signed_path
          Rails.logger.info('IncreaseCompensation::ToPdf moving files', { from_path: signed_path, to_path: pdf_path })
          # Pdf Stamper changes the file name so change it back here
          FileUtils.mv(signed_path, pdf_path, force: true)
        end
      end
      Rails.logger.info('IncreaseCompensation::ToPdf final', { path: pdf_path })
      pdf_path
    end

    ##
    # Class name for notification email
    # @return [Class]
    def send_email(email_type)
      IncreaseCompensation::NotificationEmail.new(id).deliver(email_type)
    end
  end
end
