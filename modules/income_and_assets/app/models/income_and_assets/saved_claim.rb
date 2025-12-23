# frozen_string_literal: true

require 'income_and_assets/benefits_intake/submit_claim_job'
require 'pdf_fill/filler'

module IncomeAndAssets
  ##
  # IncomeAndAssets 21P-0969 Active::Record
  # @see app/model/saved_claim
  #
  class SavedClaim < ::SavedClaim
    # Income and Assets Form ID
    FORM = IncomeAndAssets::FORM_ID

    before_validation :populate_has_property

    # @see ::SavedClaim#form_schema
    # @see ::VetsJsonSchema::SCHEMAS
    def form_schema
      MultiJson.load(File.read(IncomeAndAssets::FORM_SCHEMA))
    end

    # the predefined regional office address
    #
    # @return [Array<String>] the address lines of the regional office
    def regional_office
      ['Department of Veteran Affairs',
       'Pension Intake Center',
       'P.O. Box 5365',
       'Janesville, Wisconsin 53547-5365']
    end

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

    # Utility function to retrieve veteran filenumber/ssn
    #
    # @return [String]
    def veteran_filenumber
      parsed_form['vaFileNumber'] || parsed_form['veteranSocialSecurityNumber']
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

    # claim attachment property list
    #
    # @see PersistentAttachment
    #
    # @return [Array<String>] list of attachments
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

    # Generates a PDF from the saved claim data
    #
    # @param file_name [String, nil] Optional name for the output PDF file
    # @param fill_options [Hash] Additional options for PDF generation
    #
    # @return [String] Path to the generated PDF file
    def to_pdf(file_name = nil, fill_options = {})
      ::PdfFill::Filler.fill_form(self, file_name, fill_options)
    end

    # send an email of email_type for _this_ claim
    #
    # @param email_type [Symbol] the type of email to deliver; one defined in Settings
    def send_email(email_type)
      IncomeAndAssets::NotificationEmail.new(id).deliver(email_type)
    end

    # set the values in the form data for the hasXXX properties
    def populate_has_property
      data = parsed_form

      before_property_validation = proc do |data, property, _property_schema, parent|
        has_prop = "has#{property.upcase_first}"
        value = data[property]
        data[has_prop] = value.present? if parent['properties'][has_prop].present?
      end
      JSONSchemer.schema(form_schema, insert_property_defaults: true, before_property_validation:).validate(data)

      self.form = data.to_json
    end
  end
end
