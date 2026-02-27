# frozen_string_literal: true

require 'survivors_benefits/benefits_intake/submit_claim_job'
require 'pdf_fill/filler'

module SurvivorsBenefits
  class SavedClaim < ::SavedClaim
    # SurvivorsBenefits 21P-534EZ Active::Record
    # @see app/model/saved_claim
    #
    include HasStructuredData

    # Survivors Benefits Form ID
    FORM = SurvivorsBenefits::FORM_ID

    # the predefined regional office address
    #
    # @return [Array<String>] the address lines of the regional office
    def regional_office
      ['Department of Veteran\'s Affairs',
       'Pension Intake Center',
       'P.O. Box 5365',
       'Janesville, Wisconsin 53547-5365']
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
      1292
    end

    # Utility function to retrieve claimant email from form
    #
    # @return [String] the claimant email
    def email
      parsed_form['email'] || 'test@example.com' # TODO: update this when we have a real email field
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

    # Utility function to retrieve claimant first name from form
    #
    # @return [String]
    def claimant_first_name
      parsed_form.dig('claimantFullName', 'first')
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
      return unless pdf_path

      form_data = form.present? ? parsed_form : {}

      SurvivorsBenefits::PdfFill::Va21p534ez.stamp_signature(pdf_path, form_data)
    end

    ##
    # Class name for notification email
    # @return [Class]
    def send_email(email_type)
      SurvivorsBenefits::NotificationEmail.new(id).deliver(email_type)
    end

    # BEGIN IBM

    ##
    # Converts the form_data into json that can be read by the IBM - GOVCIO mms connection
    #
    def to_ibm
      structured_data_service = SurvivorsBenefits::StructuredData::StructuredDataService.new(parsed_form)
      structured_data_service.build_structured_data
    end

    ##
    # Section X
    # Build the medical, last, and/or burial expenses structured data entries.
    #
    # @param form [Hash]
    # @return [Hash]
    def build_medical_last_burial_expenses(form)
      fields = y_n_pair(reportable_reimbursment?(form), 'UNREIMBURSED_MED_EXPENSES_Y', 'UNREIMBURSED_MED_EXPENSES_N')
      fields.merge!(build_care_expense_fields(form['careExpenses'] || []))
            .merge!(build_medical_expense_fields(form['medicalExpenses'] || []))
    end

    ##
    # Section XI
    # Build claimant direct deposit structured data entries.
    #
    # @param form [Hash]
    # @return [Hash]
    def build_claimant_direct_deposit_fields(account)
      return {} unless account

      {
        'NAME_FINANCIAL_INSTITUTE' => account['bankName'],
        'ROUTING_TRANSIT_NUMBER' => account['routingNumber'],
        'CHECKING_ACCOUNT_CB' => account['accountType'] == 'CHECKING',
        'SAVINGS_ACCOUNT_CB' => account['accountType'] == 'SAVINGS',
        'NO_ACCOUNT_CB' => account['accountType'] == 'NO_ACCOUNT',
        'AccountNumber' => account['accountNumber']
      }
    end

    ##
    # Section XII
    # Build claim certification structured data entries.
    #
    # @param form [Hash]
    # @return [Hash]
    def build_claim_certification_fields(form)
      {
        'CB_FURTHER_EVD_CLAIM_SUPPORT' => false,
        'CLAIM_TYPE_FULLY_DEVELOPED_CHK' => true,
        'CLAIMANT_SIGNATURE_X' => form['claimantSignatureX'],
        'CLAIMANT_SIGNATURE' => form['claimantSignature'],
        'DATE_OF_CLAIMANT_SIGNATURE' => format_date(form['claimantSignatureDate'])
      }
    end
  end
end
