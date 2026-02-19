# frozen_string_literal: true

require 'survivors_benefits/benefits_intake/submit_claim_job'
require 'pdf_fill/filler'
require_relative '../../../../concerns/has_structured_data'

module SurvivorsBenefits
  ##
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

    # Number of previous marriages rows expected
    VET_PREVIOUS_MARRIAGE_COUNT = 2
    CALIMANT_PREVIOUS_MARRIAGE_COUNT = 2

    # Number of dependant childern rows expected
    DEPENDANT_CHILDREN_COUNT = 3

    # Number of DIC treatment facility rows expected
    TREATMENT_FACILITY_COUNT = 3

    # Number of income and asset rows expected
    INCOME_AND_ASSETS_COUNT = 4

    # Number of in-home or care facility rows expected
    IN_HOME_OR_CARE_FACILITY_COUNT = 3

    # Number of medical, last, and/or burial expense rows expected
    MEDICAL_LAST_BURIAL_EXPENSE_COUNT = 6

    ##
    # Converts the form_data into json that can be read by the IBM - GOVCIO mms connection
    #
    def to_ibm
      build_ibm_payload(parsed_form)
    end

    def build_ibm_payload(form)

      build_veteran_fields(form)
        .merge!(build_claimant_fields(form))

    end

    def build_veteran_fields(form)
      veterans_name = build_name(form['veteranFullName'])
      {
        'VETERAN_NAME' => veterans_name[:full],
        'VETERAN_FIRST_NAME' => veterans_name[:first],
        'VETERAN_MIDDLE)INITIAL' => veterans_name[:middle_initial],
        'VETERAN_LAST_NAME' => veterans_name[:last],
        'VETERAN_SSN' => form['veteranSocialSecurityNumber'],
        'VETERAN_DOB' => format_date(form['veteranDateOfBirth']),
        'VETSPCHPAR_FILECLAIM_Y' => form['vaClaimsHistory'] == true,
        'VETSPCHPAR_FILECLAIM_N' => form['vaClaimsHistory'] == false,
        'VA_FILE_NUMBER' => form['vaFileNumber'],
        'VETDIED_ACTIVEDUTY_Y' => form['diedOnDuty'] == true,
        'VETDIED_ACTIVEDUTY_N' => form['diedOnDuty'] == false,
        'VETERANS_SERVICE_NUMBER' => form['veteranServiceNumber'],
        'VETERAN_DATE_OF_DEATH' => format_date(form['veteranDateOfDeath'])
      }
    end

    def build_claimant_fields(form)
      claimant_name = build_name(form['claimantFullName'])
      claimant_phone = form['claimantPhone']
      {
        'CLAIMANT_NAME' => claimant_name[:full],
        'CLAIMANT_FIRST_NAME' => claimant_name[:first],
        'CLAIMANT_MIDDLE_INITIAL' => claimant_name[:middle_initial],
        'CLAIMANT_LAST_NAME' => claimant_name[:last],
        'RELATIONSHIP_SURVIVING_SPOUSE' => form['claimantRelationship'] == 'SURVIVING_SPOUSE',
        'RELATIONSHIP_CHILD' => form['claimantRelationship'] == 'CHILD_18-23_IN_SCHOOL',
        'RELATIONSHIP_CUSTODIAN' => form['claimantRelationship'] == 'CUSTODIAN_FILING_FOR_CHILD_UNDER_18',
        'RELATIONSHIP_HELPLESSCHILD' => form['claimantRelationship'] == 'HELPLESS_ADULT_CHILD',
        'CLAIMANT_SSN' => form['claimantSocialSecurityNumber'],
        'CLAIMANT_DOB' => format_date(form['claimantDateOfBirth']),
        'CLAIMANT_VETERAN_Y' => form['claimantIsVeteran'] == true,
        'CLAIMANT_VETERAN_N' => form['claimantIsVeteran'] == false,
        'CLAIMANT_ADDRESS_FULL_BLOCK' => build_address_block(form['claimantAddress']),
        'CLAIMANT_ADDRESS_LINE1' => form['claimantAddress']['street'],
        'CLAIMANT_ADDRESS_LINE2' => form['claimantAddress']['street2'],
        'CLAIMANT_ADDRESS_CITY' => form['claimantAddress']['city'],
        'CLAIMANT_ADDRESS_STATE' => form['claimantAddress']['state'],
        'CLAIMANT_ADDRESS_COUNTRY' => form['claimantAddress']['country'],
        'CLAIMANT_ADDRESS_ZIP5' => form['claimantAddress']['postalCode']['firstFive'],
        'PHONE_NUMBER' => claimant_phone,
        'INT_PHONE_NUMBER' => international_phone_number(form, claimant_phone),
        'EMAIL' => form['claimantEmail'],
        'CLAIM_TYPE_DIC' => form['claims']['DIC'],
        'CLAIM_TYPE_SURVIVOR_PENSION' => form['claims']['survivorsPension'],
        'CLAIM_TYPE_ACCRUED_BENEFITS' => form['claims']['accruedBenefits']
      }
    end
  end
end
