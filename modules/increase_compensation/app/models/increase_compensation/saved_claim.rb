# frozen_string_literal: true

require 'increase_compensation/benefits_intake/submit_claim_job'
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
      ['Department of Veterans Affairs',
       'Evidence Intake Center',
       'P.O. Box 4444',
       'Janesville, Wisconsin 53547-4444']
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
      parsed_form['email']
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

      Lighthouse::SubmitBenefitsIntakeClaim.perform_async(id)
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

      # Quick solution to the highschool education bug where the pdf form is missing the option for 9th grade
      # need to save to the right file
      # pdf = ::PdfFill::Filler.fill_form(self, file_name, fill_options)
      # if JSON.parse(form)['education']['highSchool'] == 12
      #   pdf = CombinePDF.load(pdf)
      #   pdf.pages[2].textbox('x', { width: 5, height: 5, x: 190, y: 310 })
      #   pdf.save(file_name || '21-8940V1')
      # end
      # pdf
    end

    ##
    # Class name for notification email
    # @return [Class]
    def send_email(email_type)
      IncreaseCompensation::NotificationEmail.new(id).deliver(email_type)
    end
  end
end
