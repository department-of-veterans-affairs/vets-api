# frozen_string_literal: true

require 'hca/validations'

module HCA
  # rubocop:disable Metrics/ModuleLength
  module EnrollmentSystem
    module_function

    RACE_CODES = {
      'isAmericanIndianOrAlaskanNative' => '1002-5',
      'isAsian' => '2028-9',
      'isBlackOrAfricanAmerican' => '2054-5',
      'isNativeHawaiianOrOtherPacificIslander' => '2076-8',
      'isWhite' => '2106-3'
    }.freeze

    NO_RACE = '0000-0'

    EXPOSURE_MAPPINGS = {
      'exposureToAirPollutants' => 'Air Pollutants',
      'exposureToChemicals' => 'Chemicals',
      'exposureToContaminatedWater' => 'Contaminated Water at Camp Lejeune',
      'exposureToRadiation' => 'Radiation',
      'exposureToShad' => 'SHAD',
      'exposureToOccupationalHazards' => 'Occupational Hazards',
      'exposureToAsbestos' => 'Asbestos',
      'exposureToMustardGas' => 'Mustard Gas',
      'exposureToWarfareAgents' => 'Warfare Agents',
      'exposureToOther' => 'Other'
    }.freeze

    SERVICE_BRANCH_CODES = {
      'army' => 1,
      'air force' => 2,
      'navy' => 3,
      'marine corps' => 4,
      'coast guard' => 5,
      'merchant seaman' => 7,
      'noaa' => 10,
      'space force' => 15,
      'usphs' => 9,
      'f.commonwealth' => 11,
      'f.guerilla' => 12,
      'f.scouts new' => 13,
      'f.scouts old' => 14
    }.freeze

    DISCHARGE_CODES = {
      'honorable' => 1,
      'general' => 3,
      'bad-conduct' => 6,
      'dishonorable' => 2,
      'undesirable' => 5
    }.freeze

    RELATIONSHIP_CODES = {
      'Primary Next of Kin' => 1,
      'Other Next of Kin' => 2,
      'Emergency Contact' => 3,
      'Other emergency contact' => 4,
      'Designee' => 5,
      'Beneficiary Representative' => 6,
      'Power of Attorney' => 7,
      'Guardian VA' => 8,
      'Guardian Civil' => 9,
      'Spouse' => 10,
      'Dependent' => 11
    }.freeze

    DEPENDENT_RELATIONSHIP_CODES = {
      'Spouse' => 2,
      'Son' => 3,
      'Daughter' => 4,
      'Stepson' => 5,
      'Stepdaughter' => 6,
      'Father' => 17,
      'Mother' => 18,
      'Other' => 99
    }.freeze

    # @param [String] form_id
    # Depending on the type of submission, EZ or EZR, we need to set specific form identifiers
    # Per Enrollment System staff (12/21/23)
    def form_template(form_id)
      is_ezr_submission = form_id == '10-10EZR'

      IceNine.deep_freeze(
        'va:form' => {
          '@xmlns:va' => 'http://va.gov/schema/esr/voa/v1',
          'va:formIdentifier' => {
            'va:type' => is_ezr_submission ? '101' : '100',
            'va:value' => is_ezr_submission ? '1010EZR' : '1010EZ',
            'va:version' => 2_986_360_436
          }
        },
        'va:identity' => {
          '@xmlns:va' => 'http://va.gov/schema/esr/voa/v1',
          'va:authenticationLevel' => {
            'va:type' => '100',
            'va:value' => 'anonymous'
          }
        }
      )
    end

    def financial_flag?(veteran)
      veteran['understandsFinancialDisclosure'] || veteran['discloseFinancialInformation']
    end

    def format_address(address, type: nil)
      return {} if address.blank?

      formatted = address.slice('city', 'country')
      formatted['line1'] = address['street']

      (2..3).each do |i|
        formatted["line#{i}"] = address["street#{i}"] if address["street#{i}"].present?
      end

      if address['country'] == 'USA'
        formatted['state'] = address['state']
        formatted.merge!(format_zipcode(address['postalCode']))
      else
        formatted['provinceCode'] = address['state'] || address['provinceCode']
        formatted['postalCode'] = address['postalCode']
      end

      formatted['addressTypeCode'] = type if type
      formatted
    end

    def format_zipcode(postal_code)
      return {} if postal_code.blank?

      numeric_zip = postal_code.gsub(/\D/, '')
      zip_plus_4 = numeric_zip[5..8]
      zip_plus_4 = nil if !zip_plus_4.nil? && zip_plus_4.size != 4

      {
        'zipCode' => numeric_zip[0..4],
        'zipPlus4' => zip_plus_4
      }
    end

    def marital_status_to_sds_code(marital_status)
      case marital_status
      when 'Married'
        'M'
      when 'Never Married'
        'S'
      when 'Separated'
        'A'
      when 'Widowed'
        'W'
      when 'Divorced'
        'D'
      else
        'U'
      end
    end

    def spanish_hispanic_to_sds_code(is_spanish_hispanic_latino)
      case is_spanish_hispanic_latino
      when true
        '2135-2'
      when false
        '2186-5'
      else
        '0000-0'
      end
    end

    def phone_number_from_veteran(veteran)
      return if veteran['homePhone'].blank? && veteran['mobilePhone'].blank?

      phone = []
      %w[homePhone mobilePhone].each do |type|
        number = veteran[type]

        if number.present?
          phone << {
            'phoneNumber' => number,
            'type' => (type == 'homePhone' ? '1' : '4')
          }
        end
      end

      { 'phone' => phone }
    end

    def email_from_veteran(veteran)
      email = veteran['email']
      return if email.blank?

      [
        {
          'email' => {
            'address' => email,
            'type' => '1'
          }
        }
      ]
    end

    def demographic_no?(veteran)
      veteran['hasDemographicNoAnswer'] == true
    end

    def veteran_to_races(veteran)
      races = []

      if demographic_no?(veteran)
        races << NO_RACE
      else
        RACE_CODES.each do |race_key, code|
          races << code if veteran[race_key]
        end
      end

      return if races.size.zero?

      { 'race' => races }
    end

    def veteran_to_spouse_info(veteran)
      address = format_address(veteran['spouseAddress'])
      address['phoneNumber'] = veteran['spousePhone']

      {
        'dob' => Validations.date_of_birth(veteran['spouseDateOfBirth']),
        'relationship' => 2,
        'startDate' => Validations.date_of_birth(veteran['dateOfMarriage']),
        'ssns' => {
          'ssn' => ssn_to_ssntext(veteran['spouseSocialSecurityNumber'])
        },
        'address' => address
      }.merge(convert_full_name_alt(veteran['spouseFullName']))
    end

    def income_collection_total(income_collection)
      return 0 if income_collection.blank?

      income_collection['income'].reduce(BigDecimal(0)) do |sum, collection|
        sum + BigDecimal(collection['amount'].to_s)
      end
    end

    def resource_to_income_collection(resource)
      income_collection = []

      [
        ['grossIncome', 7],
        ['netIncome', 13],
        ['otherIncome', 10]
      ].each do |income_type|
        income = resource[income_type[0]]

        if income.present?
          income_collection << {
            'amount' => income,
            'type' => income_type[1]
          }
        end
      end

      return if income_collection.size.zero?

      {
        'income' => income_collection
      }
    end

    # rubocop:disable Metrics/MethodLength
    def resource_to_expense_collection(resource, income_total)
      expense_collection = []
      expense_total = BigDecimal(0)

      [
        %w[educationExpense 3],
        %w[dependentEducationExpenses 16],
        %w[funeralExpense 19],
        %w[medicalExpense 18]
      ].each do |expense_type|
        expense = resource[expense_type[0]]

        if expense.present?
          new_expense_total = expense_total + BigDecimal(expense.to_s)
          expenses_exceeded = new_expense_total > income_total

          if expenses_exceeded
            expense = (income_total - expense_total).to_f
          else
            expense_total = new_expense_total
          end

          expense_collection << {
            'amount' => expense,
            'expenseType' => expense_type[1]
          }

          break if expenses_exceeded
        end
      end

      return if expense_collection.size.zero?

      {
        'expense' => expense_collection
      }
    end
    # rubocop:enable Metrics/MethodLength

    def dependent_relationship_to_sds_code(dependent_relationship)
      DEPENDENT_RELATIONSHIP_CODES[dependent_relationship]
    end

    def dependent_info(dependent)
      {
        'dob' => Validations.date_of_birth(dependent['dateOfBirth']),
        'relationship' => dependent_relationship_to_sds_code(dependent['dependentRelation']),
        'ssns' => {
          'ssn' => ssn_to_ssntext(dependent['socialSecurityNumber'])
        },
        'startDate' => Validations.date_of_birth(dependent['becameDependent'])
      }.merge(convert_full_name_alt(dependent['fullName']))
    end

    def dependent_financials_info(dependent)
      incomes = resource_to_income_collection(dependent)

      {
        'incomes' => incomes,
        'expenses' => resource_to_expense_collection(dependent, income_collection_total(incomes)),
        'dependentInfo' => dependent_info(dependent),
        'livedWithPatient' => dependent['cohabitedLastYear'].present?,
        'incapableOfSelfSupport' => dependent['disabledBefore18'].present?,
        'attendedSchool' => dependent['attendedSchoolLastYear'].present?,
        'contributedToSupport' => dependent['receivedSupportLastYear'].present?
      }
    end

    def veteran_to_dependent_financials_collection(veteran)
      dependents = veteran['dependents']

      if dependents.present?
        {
          'dependentFinancials' => dependents.map { |d| dependent_financials_info(d) }
        }
      end
    end

    def spouse?(veteran)
      %w[Married Separated].include?(veteran['maritalStatus'])
    end

    def veteran_to_spouse_financials(veteran)
      return if !spouse?(veteran) || !financial_flag?(veteran)

      spouse_income = resource_to_income_collection(
        'grossIncome' => veteran['spouseGrossIncome'],
        'netIncome' => veteran['spouseNetIncome'],
        'otherIncome' => veteran['spouseOtherIncome']
      )

      {
        'spouseFinancials' => {
          'incomes' => spouse_income,
          'spouse' => veteran_to_spouse_info(veteran),
          'contributedToSpousalSupport' => veteran['provideSupportLastYear'].present?,
          'livedWithPatient' => veteran['cohabitedLastYear'].present?
        }
      }
    end

    def provider_to_insurance_info(provider)
      {
        'companyName' => provider['insuranceName'],
        'policyHolderName' => provider['insurancePolicyHolderName'],
        'policyNumber' => provider['insurancePolicyNumber'],
        'groupNumber' => provider['insuranceGroupCode'],
        'insuranceMappingTypeName' => 'PI'
      }
    end

    def ssn_to_ssntext(ssn)
      {
        'ssnText' => Validations.validate_ssn(ssn)
      }
    end

    def convert_full_name(full_name)
      return {} if full_name.blank?

      {
        'firstName' => Validations.validate_name(
          data: full_name['first'],
          count: 30
        ),
        'middleName' => Validations.validate_name(
          data: full_name['middle'],
          count: 30,
          nullable: true
        ),
        'lastName' => Validations.validate_name(
          data: full_name['last'],
          count: 30
        ),
        'suffix' => Validations.validate_name(
          data: full_name['suffix']
        )
      }
    end

    def convert_full_name_alt(full_name)
      {
        'givenName' => Validations.validate_name(data: full_name['first']),
        'middleName' => Validations.validate_name(data: full_name['middle']),
        'familyName' => Validations.validate_name(data: full_name['last']),
        'suffix' => Validations.validate_name(data: full_name['suffix'])
      }
    end

    def veteran_to_person_info(veteran)
      convert_full_name(veteran['veteranFullName']).merge({
        'gender' => veteran['gender'],
        'dob' => Validations.date_of_birth(veteran['veteranDateOfBirth']),
        'mothersMaidenName' => Validations.validate_string(
          data: veteran['mothersMaidenName'],
          count: 35,
          nullable: true
        ),
        'placeOfBirthCity' => Validations.validate_string(
          data: veteran['cityOfBirth'],
          count: 20,
          nullable: true
        ),
        'placeOfBirthState' => convert_birth_state(veteran['stateOfBirth'])
      }.merge(ssn_to_ssntext(veteran['veteranSocialSecurityNumber'])))
    end

    def convert_birth_state(birth_state)
      if birth_state == 'Other'
        'FG'
      else
        birth_state
      end
    end

    def service_branch_to_sds_code(service_branch)
      SERVICE_BRANCH_CODES[service_branch] || 6
    end

    def discharge_type_to_sds_code(discharge_type)
      DISCHARGE_CODES[discharge_type] || 4
    end

    def discharge_type(veteran)
      discharge_date = Validations.parse_date(veteran['lastDischargeDate'])

      if discharge_date.present? && (discharge_date > Time.zone.now.in_time_zone('Central Time (US & Canada)').to_date)
        return ''
      end

      discharge_type_to_sds_code(veteran['dischargeType'])
    end

    def veteran_to_military_service_info(veteran)
      if veteran['lastDischargeDate'].present? && !Validations.valid_discharge_date?(veteran['lastDischargeDate'])
        raise Common::Exceptions::InvalidFieldValue.new('lastDischargeDate', veteran['lastDischargeDate'])
      end

      return_val = {
        'dischargeDueToDisability' => veteran['disabledInLineOfDuty'].present?,
        'militaryServiceSiteRecords' => { 'militaryServiceSiteRecord' => {} }
      }

      if veteran['lastServiceBranch'].present?
        return_val['militaryServiceSiteRecords']['militaryServiceSiteRecord']['militaryServiceEpisodes'] = {
          'militaryServiceEpisode' => {
            'dischargeType' => discharge_type(veteran),
            'startDate' => Validations.date_of_birth(veteran['lastEntryDate']),
            'endDate' => Validations.discharge_date(veteran['lastDischargeDate']),
            'serviceBranch' => service_branch_to_sds_code(veteran['lastServiceBranch'])
          }
        }
      end

      return_val['militaryServiceSiteRecords']['militaryServiceSiteRecord']['site'] = veteran['vaMedicalFacility']

      return_val
    end

    def veteran_to_insurance_collection(veteran)
      insurance_collection = (veteran['providers'] || []).map do |provider|
        provider_to_insurance_info(provider)
      end

      if veteran['isEnrolledMedicarePartA']
        insurance_collection << {
          'companyName' => 'Medicare',
          'enrolledInPartA' => veteran['isEnrolledMedicarePartA'],
          'insuranceMappingTypeName' => 'MDCR',
          'policyNumber' => veteran['medicareClaimNumber'],
          'partAEffectiveDate' => Validations.date_of_birth(veteran['medicarePartAEffectiveDate'])
        }.compact
      end

      return if insurance_collection.blank?

      {
        'insurance' => insurance_collection
      }
    end

    def veteran_to_enrollment_determination_info(veteran)
      {
        'eligibleForMedicaid' => veteran['isMedicaidEligible'].present?,
        'noseThroatRadiumInfo' => {
          'receivingTreatment' => veteran['radiumTreatments'].present?
        },
        'serviceConnectionAward' => {
          'serviceConnectedIndicator' => veteran['vaCompensationType'] == 'highDisability'
        },
        'specialFactors' => {
          'agentOrangeInd' => veteran['vietnamService'].present? || veteran['exposedToAgentOrange'].present?,
          'envContaminantsInd' => veteran['swAsiaCombat'].present?,
          'campLejeuneInd' => veteran['campLejeune'].present?,
          'radiationExposureInd' =>
            veteran['exposedToRadiation'].present? || veteran['radiationCleanupEfforts'].present?
        }.merge(veteran_to_tera(veteran))
      }
    end

    def veteran_to_tera(veteran)
      return {} unless veteran['hasTeraResponse']

      {
        'supportOperationsInd' => veteran['combatOperationService'].present?
      }.merge(
        if veteran['gulfWarService'].present?
          {
            'gulfWarHazard' => {
              'gulfWarHazardInd' => veteran['gulfWarService'].present?,
              'fromDate' => Validations.parse_short_date(veteran['gulfWarStartDate']),
              'toDate' => Validations.parse_short_date(veteran['gulfWarEndDate'])
            }
          }
        else
          {}
        end
      ).merge(veteran_to_toxic_exposure(veteran))
    end

    def veteran_to_toxic_exposure(veteran)
      categories = []

      EXPOSURE_MAPPINGS.each do |k, v|
        categories << v if veteran[k].present?
      end

      return {} if categories.blank?

      {
        'toxicExposure' => {
          'exposureCategories' => {
            'exposureCategory' => categories
          },
          'otherText' => veteran['otherToxicExposure'],
          'fromDate' => Validations.parse_short_date(veteran['toxicExposureStartDate']),
          'toDate' => Validations.parse_short_date(veteran['toxicExposureEndDate'])
        }
      }
    end

    # rubocop:disable Metrics/MethodLength
    def veteran_to_financials_info(veteran)
      if financial_flag?(veteran)
        incomes = resource_to_income_collection(
          'grossIncome' => veteran['veteranGrossIncome'],
          'netIncome' => veteran['veteranNetIncome'],
          'otherIncome' => veteran['veteranOtherIncome']
        )

        {
          'incomeTest' => { 'discloseFinancialInformation' => true },
          'financialStatement' => {
            'expenses' => resource_to_expense_collection(
              {
                'educationExpense' => veteran['deductibleEducationExpenses'],
                'funeralExpense' => veteran['deductibleFuneralExpenses'],
                'medicalExpense' => veteran['deductibleMedicalExpenses']
              },
              income_collection_total(incomes)
            ),
            'incomes' => incomes,
            'spouseFinancialsList' => veteran_to_spouse_financials(veteran),
            'marriedLastCalendarYear' => veteran['maritalStatus'] == 'Married',
            'dependentFinancialsList' => veteran_to_dependent_financials_collection(veteran),
            'numberOfDependentChildren' => veteran['dependents']&.size
          }
        }
      else
        {
          'incomeTest' => { 'discloseFinancialInformation' => false }
        }
      end
    end
    # rubocop:enable Metrics/MethodLength

    def relationship_to_contact_type(relationship)
      RELATIONSHIP_CODES[relationship]
    end

    def dependent_to_association(dependent)
      {
        'contactType' => relationship_to_contact_type('Dependent'),
        'relationship' => dependent['dependentRelation']
      }.merge(convert_full_name_alt(dependent['fullName']))
    end

    def spouse_to_association(veteran)
      if spouse?(veteran) && financial_flag?(veteran)
        {
          'address' => format_address(veteran['spouseAddress']),
          'contactType' => relationship_to_contact_type('Spouse'),
          'relationship' => 'SPOUSE'
        }.merge(convert_full_name_alt(veteran['spouseFullName']))
      end
    end

    def veteran_contacts_to_association(contact)
      {
        'contactType' => relationship_to_contact_type(contact['contactType']),
        'relationship' => contact['relationship'],
        'address' => format_address(contact['address']),
        'primaryPhone' => contact['primaryPhone'],
        'alternatePhone' => contact['alternatePhone']
      }.merge(convert_full_name_alt(contact['fullName']))
    end

    def veteran_to_association_collection(veteran)
      associations = []

      dependents_list = veteran['dependents'] || []

      dependents = dependents_list.map do |dependent|
        dependent_to_association(dependent)
      end.compact

      spouse = spouse_to_association(veteran)

      # Next of kin and emergency contacts
      contacts_list = veteran['veteranContacts'] || []
      contacts = contacts_list.map do |contact|
        veteran_contacts_to_association(contact)
      end.compact

      associations += dependents.concat(contacts)
      associations << spouse if spouse.present?

      return if associations.blank?

      { 'association' => associations }
    end

    def address_from_veteran(veteran)
      veteran_address = veteran['veteranAddress']
      home_address    = veteran['veteranHomeAddress']
      address         = if home_address
                          [
                            format_address(veteran_address, type: 'P'),
                            format_address(home_address, type: 'R')
                          ]
                        else
                          format_address(veteran_address, type: 'P')
                        end

      { 'address' => address }
    end

    def veteran_to_ethnicity(veteran)
      if veteran.key?('hasDemographicNoAnswer') || veteran.key?('isSpanishHispanicLatino')
        if demographic_no?(veteran)
          NO_RACE
        else
          spanish_hispanic_to_sds_code(veteran['isSpanishHispanicLatino'])
        end
      end
    end

    def veteran_to_demographics_info(veteran)
      return_val = {
        'appointmentRequestResponse' => veteran['wantsInitialVaContact'].present?,
        'contactInfo' => {
          'addresses' => address_from_veteran(veteran),
          'emails' => email_from_veteran(veteran),
          'phones' => phone_number_from_veteran(veteran)
        },
        'ethnicity' => veteran_to_ethnicity(veteran),
        'maritalStatus' => marital_status_to_sds_code(veteran['maritalStatus']),
        'preferredFacility' => veteran['vaMedicalFacility'],
        'races' => veteran_to_races(veteran),
        'acaIndicator' => veteran['isEssentialAcaCoverage'].present?
      }

      return_val.delete('ethnicity') if return_val['ethnicity'].nil?

      return_val
    end

    def veteran_to_summary(veteran)
      data = {
        'associations' => veteran_to_association_collection(veteran),
        'demographics' => veteran_to_demographics_info(veteran),
        'enrollmentDeterminationInfo' => veteran_to_enrollment_determination_info(veteran),
        'financialsInfo' => veteran_to_financials_info(veteran),
        'insuranceList' => veteran_to_insurance_collection(veteran),
        'militaryServiceInfo' => veteran_to_military_service_info(veteran),
        'prisonerOfWarInfo' => {
          'powIndicator' => veteran['isFormerPow'].present?
        },
        'purpleHeart' => {
          'indicator' => veteran['purpleHeartRecipient'].present?
        },
        'personInfo' => veteran_to_person_info(veteran)
      }
      data = prepend_namespace(data)
      # This *must* be a symbol. It's a special flag for the Goyuko library.
      data[:attributes!] = data.keys.index_with do |_attribute|
        { 'xmlns:eeSummary' => 'http://jaxws.webservices.esr.med.va.gov/schemas' }
      end
      data
    end

    def prepend_namespace(data)
      case data
      when Hash
        data.each_with_object({}) do |(k, v), memo|
          memo["eeSummary:#{k}"] = prepend_namespace(v)
        end
      when Array
        data.map { |i| prepend_namespace(i) }
      else
        data
      end
    end

    def convert_value!(value)
      if value.is_a?(Hash)
        convert_hash_values!(value)
      elsif value.is_a?(Array)
        result = value.map do |item|
          convert_value!(item)
        end
        result.compact_blank!
      elsif value.in?([true, false]) || value.is_a?(Numeric)
        value.to_s
      else
        value
      end
    end

    def convert_hash_values!(hash)
      hash.each do |k, v|
        hash[k] = convert_value!(v)
      end
      hash.compact_blank!
    end

    def get_user_variables(user_identifier)
      return [nil, nil] if user_identifier.blank?

      icn = user_identifier['icn']
      edipi = user_identifier['edipi']

      if icn
        [icn, 1]
      elsif edipi
        [edipi, 2]
      else
        [nil, nil]
      end
    end

    def build_form_for_user(user_identifier, form_id)
      form = form_template(form_id).deep_dup

      (user_id, id_type) = get_user_variables(user_identifier)
      return form if user_id.nil?

      authentication_level = form['va:identity']['va:authenticationLevel']
      authentication_level['va:type'] = '102'
      authentication_level['va:value'] = 'Assurance Level 2'

      form['va:identity']['va:veteranIdentifier'] = {
        'va:type' => id_type,
        'va:value' => user_id.to_s
      }
      form
    end

    def copy_spouse_address!(veteran)
      veteran['spouseAddress'] = veteran['veteranAddress'] if veteran['spouseAddress'].blank?
      veteran
    end

    def remove_ctrl_chars!(value)
      case value
      when Hash
        value.each do |k, v|
          value[k] = remove_ctrl_chars!(v)
        end
      when Array
        value.map! { |i| remove_ctrl_chars!(i) }
      when String
        value.tr("\u0000-\u001f\u007f\u2028", '')
      end
    end

    def get_va_format(content_type)
      # ES only accepts these strings for 'va:format': PDF,WORD,JPG,RTF
      extension = MIME::Types[content_type]&.first&.extensions&.first

      if extension&.include?('doc')
        'WORD'
      elsif extension == 'jpeg'
        'JPG'
      elsif extension == 'rtf'
        'RTF'
      else
        'PDF'
      end
    end

    def add_attachment(file, id, is_dd214)
      {
        'va:document' => {
          'va:name' => "Attachment_#{id}",
          'va:format' => get_va_format(file.content_type),
          'va:type' => is_dd214 ? '1' : '5',
          'va:content' => Base64.encode64(file.read)
        }
      }
    end

    # @param [Hash] veteran data in JSON format
    # @param [Hash] user_identifier
    # @param [String] form_id
    def veteran_to_save_submit_form(
      veteran,
      user_identifier,
      form_id
    )
      return {} if veteran.blank?

      copy_spouse_address!(veteran)

      request = build_form_for_user(user_identifier, form_id)

      veteran['attachments']&.each_with_index do |attachment, i|
        guid = attachment['confirmationCode']
        form_attachment = HCAAttachment.find_by(guid:) || Form1010EzrAttachment.find_by(guid:)

        next if form_attachment.nil?

        request['va:form']['va:attachments'] ||= []
        request['va:form']['va:attachments'] << add_attachment(form_attachment.get_file, i + 1, attachment['dd214'])
      end

      request['va:form']['va:summary'] = veteran_to_summary(veteran)
      request['va:form']['va:applications'] = {
        'va:applicationInfo' => [{
          'va:appDate' => Time.now.in_time_zone('Central Time (US & Canada)').strftime('%Y-%m-%d'),
          'va:appMethod' => '1'
        }]
      }

      convert_hash_values!(request)
      remove_ctrl_chars!(request)
      request
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
