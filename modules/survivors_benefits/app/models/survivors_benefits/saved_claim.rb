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

    # Build the structured data dictionary payload from the parsed claim form.
    #
    # @param form [Hash]
    # @return [Hash]
    ##
    def build_ibm_payload(form)
      build_veterans_id_info(form)
        .merge!(build_claimants_id_info(form))
        .merge!(build_veterans_service_info(form))
        .merge!(build_marital_info(form))
        .merge!(build_marital_history_fields(form))
    end

    ##
    # Section I
    # Build the veteran-specific structured data entries.
    #
    # @param form [Hash]
    # @return [Hash]
    def build_veterans_id_info(form)
      build_name_fields(form['veteranFullName'], 'VETERAN')
        .merge!(radio_value(form['vaClaimsHistory'], 'VETSPCHPAR_FILECLAIM_Y', 'VETSPCHPAR_FILECLAIM_N'))
        .merge!(radio_value(form['diedOnDuty'], 'VETDIED_ACTIVEDUTY_Y', 'VETDIED_ACTIVEDUTY_N'))
        .merge!(
          {
            'VETERAN_SSN' => form['veteranSocialSecurityNumber'],
            'VETERAN_DOB' => format_date(form['veteranDateOfBirth']),
            'VA_FILE_NUMBER' => form['vaFileNumber'],
            'VETERANS_SERVICE_NUMBER' => form['veteranServiceNumber'],
            'VETERAN_DATE_OF_DEATH' => format_date(form['veteranDateOfDeath'])
          }
        )
    end

    ##
    # Section II
    # Build the claimant-specific structured data entries.
    #
    # @param form [Hash]
    # @return [Hash]
    def build_claimants_id_info(form)
      primary_phone = { 'contact' => form['claimantPhone'], 'countryCode' => form['claimantAddress']['country'] }
      build_name_fields(form['claimantFullName'], 'CLAIMANT')
        .merge!(build_claimant_address_fields(form['claimantAddress']))
        .merge!(build_relationship(form['claimantRelationship']))
        .merge!(build_claim_type_fields(form['claims']))
        .merge!(radio_value(form['claimantIsVeteran'], 'CLAIMANT_IS_VETERAN_YES', 'CLAIMANT_IS_VETERAN_NO'))
        .merge!(
          {
            'CLAIMANT_SSN' => form['claimantSocialSecurityNumber'],
            'CLAIMANT_DOB' => format_date(form['claimantDateOfBirth']),
            'PHONE_NUMBER' => primary_phone['contact'],
            'INT_PHONE_NUMBER' => international_phone_number(form, primary_phone),
            'EMAIL' => form['claimantEmail']
          }
        )
    end

    ##
    # Section III
    # Build the veteran service info structured data entries.
    #
    # @param form [Hash]
    # @return [Hash]
    def build_veterans_service_info(form)
      build_vet_aliases(form['veteranPreviousNames'].length.positive?, form['veteranPreviousNames'])
        .merge!(build_service_branch_fields(form['serviceBranch']))
        .merge!(radio_value(form['nationalGuardActivated'], 'ACTIVATED_TO_FED_DUTY_YES', 'ACTIVATED_TO_FED_DUTY_NO'))
        .merge!(radio_value(form['pow'], 'POW_YES', 'POW_NO'))
        .merge!(
          {
            'DATE_ENTERED_TO_SERVICE' => format_date(form['activeServiceDateRange']['from']),
            'DATE_SEPARATED_FROM_SERVICE' => format_date(form['activeServiceDateRange']['to']),
            'PLACE_SEPARATED_FROM_SERVICE_1' => form['placeOfSeparation'],
            'DATE_OF_ACTIVATION' => format_date(form['nationalGuardActivationDate']),
            'NAME_ADDRESS_RESERVE_UNIT' => form['unitNameAndAddress'],
            'RESERVE_PHONE_NUMBER' => form['unitPhone'],
            'DATE_OF_CONFINEMENT_START' => form['pow'] ? format_date(form['powDateRange']['from']) : nil,
            'DATE_OF_CONFINEMENT_END' => form['pow'] ? format_date(form['powDateRange']['to']) : nil
          }
        )
    end

    ##
    # Section IV
    # Build the marital information structured data entries.
    #
    # @param form [Hash]
    # @return [Hash]
    def build_marital_info(form)
      pregnant_with_veteran, lived_with_veteran, discordant_separation, marriage_type = marital_info_data(form)
      build_claimant_remarriage_fields(form)
        .merge!(radio_value(form['validMarriage'], 'AWARE_OF_MARRIAGE_VALIDITY_YES', 'AWARE_OF_MARRIAGE_VALIDITY_NO'))
        .merge!(build_veteran_separation_fields(form))
        .merge!(radio_value(form['childWithVeteran'], 'CHILD_DURING_MARRIAGE_YES', 'CHILD_DURING_MARRIAGE_NO'))
        .merge!(radio_value(pregnant_with_veteran, 'EXPECTING_BIRTH_VET_CHILD_YES', 'EXPECTING_BIRTH_VET_CHILD_NO'))
        .merge!(radio_value(lived_with_veteran, 'LIVE_WITH_VET_TILL_DEATH_YES', 'LIVED_WITH_VET_CONTINUOUSLY_NO'))
        .merge!(radio_value(discordant_separation, 'MARITAL_DISCORD_SEPARATION_Y', 'MARITAL_DISCORD_SEPARATION_N'))
        .merge!(radio_value(marriage_type == 'ceremonial', 'CB_CL_MARR_1_TYPE_CEREMONIAL', 'CB_CL_MARR_1_TYPE_OTHER'))
        .merge!(
          {
            'VET_CLAIMANT_MARRIAGE_1_DATE' => format_date(form.dig('marriageDates', 'from')),
            'VET_CLAIMANT_MARRIAGE_1_DATE_ENDED' => format_date(form.dig('marriageDates', 'to')),
            'VET_CLAIMANT_MARRIAGE_1_PLACE' => form['placeOfMarriage'],
            'VET_CLAIMANT_MARRIAGE_1_PLACE_ENDED' => form['placeOfMarriageTermination'],
            'CL_MARR_1_TYPE_OTHEREXPLAIN' => form['marriageTypeExplanation'],
            'MARITAL_DISCORD_SEPARATION_EXP' => form['separationExplanation']
          }
        )
    end

    ##
    # Section V
    # Build_marital_history_fields(form)
    # Build the marital history structured data entries.
    #
    # @param form [Hash]
    # @return [Hash]
    def build_marital_history_fields(form)
      vet_prev_marriages = form['veteranMarriages'] || []
      spouse_prev_marriages = form['spouseMarriages'] || []
      build_previous_marriage_fields(form, vet_prev_marriages, 'VETERAN', 'veteranHasAdditionalMarriages')
        .merge!(build_previous_marriage_fields(form, spouse_prev_marriages, 'CLAIMANT', 'spouseHasAdditionalMarriages'))
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

    def build_relationship(relationship)
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

    def build_vet_aliases(has_aliases, aliases = [])
      n1 = aliases[0] || {}
      n2 = aliases[1] || {}
      alias_fields = {
        'VET_NAME_OTHER_Y' => has_aliases == true,
        'VET_NAME_OTHER_N' => has_aliases == false,
        'VET_NAME_OTHER_1' => [n1['first'], n1['middle'], n1['last'], n1['suffix']].compact.join(' ').presence,
        'VET_NAME_OTHER_2' => [n2['first'], n2['middle'], n2['last'], n2['suffix']].compact.join(' ').presence
      }
      radio_value(has_aliases, 'VET_NAME_OTHER_Y', 'VET_NAME_OTHER_N')
        .merge!(alias_fields)
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
        'BRANCH_OF_SERVICE_USPHS' => branch == 'noaa'
      }
    end

    def build_veteran_separation_fields(form)
      married_at_death = form['marriedToVeteranAtTimeOfDeath']
      result =
        if married_at_death
          {
            'CB_MARR_TO_VET_ENDED_DEATH' => form['howMarriageEnded'] == 'death',
            'CB_MARR_TO_VET_ENDED_DIVORCE' => form['howMarriageEnded'] == 'divorce',
            'CB_MARR_TO_VET_ENDED_OTHER' => form['howMarriageEnded'] == 'other',
            'MARR_TO_VET_ENDED_OTHEREXPLAIN' => form['howMarriageEndedExplanation']
          }
        else
          {}
        end
      result.merge!(radio_value(married_at_death, 'MARRIED_WHILE_VET_DEATH_Y', 'MARRIED_WHILE_VET_DEATH_N'))
    end

    def build_claimant_remarriage_fields(form)
      has_remarried = form['remarriageAfterVeteralDeath']
      expand_remarriage_end_cause(has_remarried, form['remarriageEndCause'])
        .merge!(radio_value(has_remarried, 'REMARRIED_AFTER_VET_DEATH_YES', 'REMARRIED_AFTER_VET_DEATH_NO'))
        .merge!(radio_value(form['claimantHasAdditionalMarriages'], 'ADDITIONAL_MARRIAGES_Y', 'ADDITIONAL_MARRIAGES_N'))
        .merge!(
          {
            'CLAIMANT_REMARRIAGE_1_DATE' => format_date(form.dig('remarriageDates', 'from')),
            'CLAIMANT_REMARRIAGE_1_DATE_ENDED' => format_date(form.dig('remarriageDates', 'to')),
            'REMARRIAGE_OTHER_EXPLANATION' => form['remarriageEndCauseExplanation']
          }
        )
    end

    def expand_remarriage_end_cause(has_remarried, remarriage_end_cause)
      {
        'CB_REMARRIAGE_END_BY_DEATH' => has_remarried ? remarriage_end_cause == 'death' : nil,
        'CB_REMARRIAGE_END_BY_DIVORCE' => has_remarried ? remarriage_end_cause == 'divorce' : nil,
        'CB_MARRIAGE_DID_NOT_END' => has_remarried ? remarriage_end_cause == 'didNotEnd' : nil,
        'CB_REMARRIAGE_END_BY_OTHER' => has_remarried ? remarriage_end_cause == 'other' : nil
      }
    end

    def marital_info_data(form)
      [
        form['pregnantWithVeteran'],
        form['livedContinuouslyWithVeteran'],
        form['separationDueToAssignedReasons'],
        form['marriageType']
      ]
    end

    def build_previous_marriage_fields(form, marriages, individual, add_marr_field)
      indv = individuals_permutations(individual)
      additional_marriages_yes, additional_marriages_no = additional_marriages_boolean_fields(individual)
      fields = radio_value(form[add_marr_field], additional_marriages_yes, additional_marriages_no)
      marriages.each_with_index do |marriage, index|
        fields
          .merge!(build_spouse_name_fields(marriage['spouseFullName'], indv[:l], index + 1))
          .merge!(
            {
              "CB_#{indv[:s]}_MARR#{index + 1}_ENDED_DEATH" => marriage['reasonForSeparation'] == 'DEATH',
              "CB_#{indv[:s]}_MARR#{index + 1}_ENDED_DIVORCE" => marriage['reasonForSeparation'] == 'DIVORCE',
              "CB_#{indv[:s]}_MARR#{index + 1}_ENDED_OTHER" => marriage['reasonForSeparation'] == 'OTHER',
              "#{indv[:m]}_MARR#{index + 1}_ENDED_OTHEREXPLAIN" => marriage['reasonForSeparationExplanation'],
              "#{indv[:l]}_MARRIAGE_#{index + 1}_DATE" => format_date(marriage['dateOfMarriage']),
              "#{indv[:l]}_MARRIAGE_#{index + 1}_DATE_ENDED" => format_date(marriage['dateOfSeparation']),
              "#{indv[:l]}_MARRIAGE_#{index + 1}_PLACE" => marriage['locationOfMarriage'],
              "#{indv[:l]}_MARRIAGE_#{index + 1}_PLACE_ENDED" => marriage['locationOfSeparation']
            }
          )
      end
      fields
    end

    def individuals_permutations(individual)
      if individual == 'VETERAN'
        {
          s: 'VET',
          m: 'VET',
          l: 'VETERAN'
        }
      elsif individual == 'CLAIMANT'
        {
          s: 'CL',
          m: 'CB_CL',
          l: 'CLAIMANT'
        }
      end
    end

    def additional_marriages_boolean_fields(individual)
      ["#{individual}_ADDITIONAL_MARRIAGES_Y", "#{individual}_ADDITIONAL_MARRIAGES_N"]
    end

    def build_spouse_name_fields(name, individual, marriage_num)
      spouse_name = build_name(name)
      {
        "#{individual}_MARRIAGE_#{marriage_num}_TO" => spouse_name[:full],
        "#{individual}_MARRIAGE_#{marriage_num}_TO_FIRST_NAME" => spouse_name[:first],
        "#{individual}_MARRIAGE_#{marriage_num}_TO_MID_INT" => spouse_name[:middle_initial],
        "#{individual}_MARRIAGE_#{marriage_num}_TO_LAST_NAME" => spouse_name[:last]
      }
    end

    def radio_value(field, yes, no)
      return {} if field.nil?

      {
        yes => field == true,
        no => field == false
      }
    end
  end
end
