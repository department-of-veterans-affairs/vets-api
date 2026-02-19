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
      build_veterans_id_info(form)
        .merge!(build_claimants_id_info(form))
        .merge!(build_veterans_service_info(form))
    end

    def build_veterans_id_info(form)
      name_fields = build_name_fields(form['veteranFullName'], 'VETERAN')
      name_fields.merge!(
        {
          'VETERAN_SSN' => form['veteranSocialSecurityNumber'],
          'VETERAN_DOB' => format_date(form['veteranDateOfBirth']),
          'VETSPCHPAR_FILECLAIM_Y' => form['vaClaimsHistory'] ? form['vaClaimsHistory'] == true : nil,
          'VETSPCHPAR_FILECLAIM_N' => form['vaClaimsHistory'] ? form['vaClaimsHistory'] == false : nil,
          'VA_FILE_NUMBER' => form['vaFileNumber'],
          'VETDIED_ACTIVEDUTY_Y' => form['diedOnDuty'] ? form['diedOnDuty'] == true : nil,
          'VETDIED_ACTIVEDUTY_N' => form['diedOnDuty'] ? form['diedOnDuty'] == false : nil,
          'VETERANS_SERVICE_NUMBER' => form['veteranServiceNumber'],
          'VETERAN_DATE_OF_DEATH' => format_date(form['veteranDateOfDeath'])
        }
      )
    end

    def build_claimants_id_info(form)
      primary_phone = { 'contact' => form['claimantPhone'], 'countryCode' => form['claimantAddress']['country'] }
      build_name_fields(form['claimantFullName'], 'CLAIMANT')
        .merge!(build_claimant_address_fields(form['claimantAddress']))
        .merge!(build_relationship(form['claimantRelationship']))
        .merge!(build_claim_type_fields(form['claims']))
        .merge!(
          {
            'CLAIMANT_SSN' => form['claimantSocialSecurityNumber'],
            'CLAIMANT_DOB' => format_date(form['claimantDateOfBirth']),
            'CLAIMANT_VETERAN_Y' => form['claimantIsVeteran'] ? form['claimantIsVeteran'] == true : nil,
            'CLAIMANT_VETERAN_N' => form['claimantIsVeteran'] ? form['claimantIsVeteran'] == false : nil,
            'PHONE_NUMBER' => primary_phone['contact'],
            'INT_PHONE_NUMBER' => international_phone_number(form, primary_phone),
            'EMAIL' => form['claimantEmail']
          }
        )
    end

    def build_veterans_service_info(form)
      build_vet_aliases(form['veteranHasPreviousNames'], form['veteranPreviousNames'])
      build_service_branch_fields(form['serviceBranch'])
      {
        'DATE_ENTERED_TO_SERVICE' => format_date(form['activeServiceDateRange']['from']),
        'DATE_SEPARATED_FROM_SERVICE' => format_date(form['activeServiceDateRange']['to']),
        'PLACE_SEPARATED_FROM_SERVICE_1' => form['placeOfSeparation'],
        'ACTIVATED_TO_FED_DUTY_YES' => form['nationalGuardActivated'] ? form['nationalGuardActivated'] == true : nil,
        'ACTIVATED_TO_FED_DUTY_NO' => form['nationalGuardActivated'] ? form['nationalGuardActivated'] == false : nil,
        'DATE_OF_ACTIVATION' => format_date(form['nationalGuardActivationDate']),
        'NAME_ADDRESS_RESERVE_UNIT' => form['unitNameAndAddress'],
        'RESERVE_PHONE_NUMBER' => form['unitPhone'],
        'POW_YES' => form['pow'] ? form['pow'] == true : nil,
        'POW_NO' => form['pow'] ? form['pow'] == false : nil,
        'DATE_OF_CONFINEMENT_START' => form['pow'] ? format_date(form['powDateRange']['from']) : nil,
        'DATE_OF_CONFINEMENT_END' => form['pow'] ? format_date(form['powDateRange']['to']) : nil
      }
    end

    def build_name_fields(name, individual)
      name = build_name(name)
      {
        "#{individual}_NAME" => name[:full],
        "#{individual}_FIRST_NAME" => name[:first],
        "#{individual}_MIDDLE_INITIAL" => name[:middle_initial],
        "#{individual}_LAST_NAME" => name[:last]
      }
    end

    def build_claimant_address_fields(claimant_address)
      {
        'CLAIMANT_ADDRESS_FULL_BLOCK' => build_address_block(claimant_address),
        'CLAIMANT_ADDRESS_LINE1' => claimant_address['street'],
        'CLAIMANT_ADDRESS_LINE2' => claimant_address['street2'],
        'CLAIMANT_ADDRESS_CITY' => claimant_address['city'],
        'CLAIMANT_ADDRESS_STATE' => claimant_address['state'],
        'CLAIMANT_ADDRESS_COUNTRY' => claimant_address['country'],
        'CLAIMANT_ADDRESS_ZIP5' => claimant_address['postalCode']['firstFive']
      }
    end

    def build_relationship_fields(relationship)
      {
        'RELATIONSHIP_SURVIVING_SPOUSE' => relationship == 'SURVIVING_SPOUSE',
        'RELATIONSHIP_CHILD' => relationship == 'CHILD_18-23_IN_SCHOOL',
        'RELATIONSHIP_CUSTODIAN' => relationship == 'CUSTODIAN_FILING_FOR_CHILD_UNDER_18',
        'RELATIONSHIP_HELPLESSCHILD' => relationship == 'HELPLESS_ADULT_CHILD'
      }
    end

    def build_claim_type_fields(claims = {})
      {
        'CLAIM_TYPE_DIC' => claims['DIC'],
        'CLAIM_TYPE_SURVIVOR_PENSION' => claims['survivorsPension'],
        'CLAIM_TYPE_ACCRUED_BENEFITS' => claims['accruedBenefits']
      }
    end

    def build_vet_aliases(has_aliases = false, aliases = [])
      alias_fields = {  
        'VET_NAME_OTHER_Y' => has_aliases == true,
        'VET_NAME_OTHER_N' => has_aliases == false,
        'VET_NAME_OTHER_1' => aliases[0],
        'VET_NAME_OTHER_2' => aliases[1]
      }
    end

    def build_service_branch_fields(branch)
      {
        'BRANCH_OF_SERVICE_ARMY' => branch == 'army',
        'BRANCH_OF_SERVICE_NAVY' => branch == 'navy',
        'BRANCH_OF_SERVICE_AIR-FORCE' => branch == 'airForce',
        'BRANCH_OF_SERVICE_MARINE' => branch == 'marineCorps',
        'BRANCH_OF_SERVICE_COAST-GUARD' => branch == 'coastGuard',
        'BRANCH_OF_SERVICE_SPACE' => branch == 'spaceForce',
        'BRANCH_OF_SERVICE_NOAA' => branch == 'usphs',
        'BRANCH_OF_SERVICE_USPHS' => branch == 'noaa',
      }
  end
end
