# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/formatters/va1010ez'

# rubocop:disable Metrics/ClassLength
module PdfFill
  module Forms
    class Va1010ez < FormBase
      FORM_ID = HealthCareApplication::FORM_ID
      OFF = 'Off'
      FORMATTER = PdfFill::Forms::Formatters::Va1010ez

      # Constants used to map data from the vets-json-schema payload to the values expected
      # by the 10-10EZ PDF form. These mappings are necessary for converting form input
      # data into the correct format for PDF generation.

      MARITAL_STATUS = {
        'Married' => 1,
        'Never Married' => 2,
        'Separated' => 3,
        'Widowed' => 4,
        'Divorced' => 5
      }.freeze

      DEPENDENT_RELATIONSHIP = {
        'Son' => 1,
        'Daughter' => 2,
        'Stepson' => 3,
        'Stepdaughter' => 4
      }.freeze

      DISABILITY_STATUS = {
        %w[highDisability lowDisability] => 'YES',
        %w[none] => 'NO'
      }.freeze

      SEX = {
        'M' => 1,
        'F' => 2
      }.freeze

      DISCLOSE_FINANCIAL_INFORMATION = {
        true => 'Yes, I will provide my household financial information' \
                ' for last calendar year. Complete applicable Sections' \
                ' VII and VIII. Sign and date the form in the Assignment' \
                ' of Benefits section.',
        false => 'No, I do not wish to provide financial information' \
                 'in Sections VII through VIII. If I am enrolled, I ' \
                 ' agree to pay applicable VA copayments. Sign and date' \
                 ' the form in the Assignment of Benefits section.'
      }.freeze

      # Exposure values correspond to true for each key in the pdf options
      EXPOSURE_MAP = {
        'exposureToAirPollutants' => 1,
        'exposureToChemicals' => 2,
        'exposureToRadiation' => 3,
        'exposureToShad' => 4,
        'exposureToOccupationalHazards' => 5,
        'exposureToAsbestos' => 5,
        'exposureToMustardGas' => 5,
        'exposureToContaminatedWater' => 6,
        'exposureToWarfareAgents' => 6,
        'exposureToOther' => 7
      }.freeze

      ETHNICITY_MAP = {
        'isAsian' => 1,
        'isAmericanIndianOrAlaskanNative' => 2,
        'isBlackOrAfricanAmerican' => 3,
        'isWhite' => 4,
        'isNativeHawaiianOrOtherPacificIslander' => 5,
        'hasDemographicNoAnswer' => 6
      }.freeze

      # All date fields on the form so we can iterate over them to format them as the pdf form expects
      # The dependent dates are not included in this list
      DATE_FIELDS = %w[
        medicarePartAEffectiveDate
        spouseDateOfBirth
        dateOfMarriage
        lastEntryDate
        lastDischargeDate
        gulfWarStartDate
        gulfWarEndDate
        agentOrangeStartDate
        agentOrangeEndDate
        veteranDateOfBirth
        toxicExposureStartDate
        toxicExposureEndDate
      ].freeze

      # KEY constant maps the `@form_data` keys to their corresponding PDF field identifiers.
      # These mappings are used to associate the form data with the correct PDF form field
      # (specified by a unique key). This ensures the data is placed in the correct field when generating the PDF.
      KEY = {
        'veteranFullName' => {
          key: 'F[0].P4[0].LastFirstMiddle[0]',
          limit: 40,
          question_num: 1.01,
          question_suffix: 'A',
          question_text: "VETERAN'S NAME (Last, First, Middle Name)"
        },
        'mothersMaidenName' => {
          key: 'F[0].P4[0].MothersMaidenName[0]',
          limit: 20,
          question_num: 1.02,
          question_text: "MOTHER'S MAIDEN NAME"
        },
        'gender' => {
          key: 'F[0].P4[0].BirthSex[0]'
        },
        'isSpanishHispanicLatino' => {
          key: 'F[0].P4[0].HispanicOrLatino[0]'
        },
        'isAmericanIndianOrAlaskanNative' => {
          key: 'F[0].P4[0].Race[0]'
        },
        'isAsian' => {
          key: 'F[0].P4[0].Race[1]'
        },
        'isWhite' => {
          key: 'F[0].P4[0].Race[2]'
        },
        'isBlackOrAfricanAmerican' => {
          key: 'F[0].P4[0].Race[3]'
        },
        'isNativeHawaiianOrOtherPacificIslander' => {
          key: 'F[0].P4[0].Race[4]'
        },
        'hasDemographicNoAnswer' => {
          key: 'F[0].P4[0].Race[5]'
        },
        'placeOfBirth' => {
          key: 'F[0].P4[0].PlaceOfBirth[0]',
          limit: 28,
          question_num: 1.07,
          question_suffix: 'B',
          question_text: 'PLACE OF BIRTH (City and State)'
        },
        'veteranAddress' =>
          {
            'street' => {
              key: 'F[0].P4[0].MailingAddress_Street[0]',
              limit: 27,
              question_num: 1.10,
              question_suffix: 'A',
              question_text: 'MAILING ADDRESS (Street)'
            },
            'city' => {
              key: 'F[0].P4[0].MailingAddress_City[0]',
              limit: 18,
              question_num: 1.10,
              question_suffix: 'B',
              question_text: 'CITY'
            },
            'postalCode' => {
              key: 'F[0].P4[0].MailingAddress_ZipCode[0]'
            },
            'state' => {
              key: 'F[0].P4[0].MailingAddress_State[0]'
            }
          },
        'homePhone' => {
          key: 'F[0].P4[0].HomeTelephoneNumber[0]'
        },
        'mobilePhone' => {
          key: 'F[0].P4[0].MbileTelephoneNumber[0]'
        },
        'email' => {
          key: 'F[0].P4[0].EmailAddress[0]'
        },
        'veteranHomeAddress' =>
          {
            'street' => {
              key: 'F[0].P4[0].HomeAddress_Street[0]',
              limit: 27,
              question_num: 1.11,
              question_suffix: 'A',
              question_text: 'HOME ADDRESS (Street)'
            },
            'city' => {
              key: 'F[0].P4[0].HomeAddress_City[0]',
              limit: 18,
              question_num: 1.11,
              question_suffix: 'B',
              question_text: 'CITY'
            },
            'postalCode' => {
              key: 'F[0].P4[0].HomeAddress_ZipCode[0]'
            },
            'state' => {
              key: 'F[0].P4[0].HomeAddress_State[0]'
            }
          },
        'maritalStatus' => {
          key: 'F[0].P4[0].CurrentMaritalStatus[0]'
        },
        'vaMedicalFacility' => {
          key: 'F[0].P4[0].PreferredVACenter[0]'
        },
        'wantsInitialVaContact' => {
          key: 'F[0].P4[0].ScheduleFirstAppointment[0]'
        },
        'purpleHeartRecipient' => {
          key: 'F[0].P4[0].Section2_2A[0]'
        },
        'isFormerPow' => {
          key: 'F[0].P4[0].Section2_2B[0]'
        },
        'postNov111998Combat' => {
          key: 'F[0].P4[0].Section2_2C[0]'
        },
        'disabledInLineOfDuty' => {
          key: 'F[0].P4[0].Section2_2D[0]'
        },
        'swAsiaCombat' => {
          key: 'F[0].P4[0].Section2_2E[0]'
        },
        'vaCompensationType' => {
          key: 'F[0].P4[0].Section2_2F[0]'
        },
        'radiationCleanupEfforts' => {
          key: 'F[0].P5[0].RadioButtonList[2]'
        },
        'gulfWarService' => {
          key: 'F[0].P5[0].RadioButtonList[3]'
        },
        'combatOperationService' => {
          key: 'F[0].P5[0].RadioButtonList[0]'
        },
        'exposedToAgentOrange' => {
          key: 'F[0].P5[0].RadioButtonList[1]'
        },
        'gulfWarStartDate' => {
          key: 'F[0].P5[0].FromDate_3B[0]'
        },
        'gulfWarEndDate' => {
          key: 'F[0].P5[0].ToDate_3B[0]'
        },
        'agentOrangeStartDate' => {
          key: 'F[0].P5[0].FromDate_3C[0]'
        },
        'agentOrangeEndDate' => {
          key: 'F[0].P5[0].ToDate_3C[0]'
        },
        'exposureToAirPollutants' => {
          key: 'F[0].P5[0].ExposedToTheFollowing[0]'
        },
        'exposureToChemicals' => {
          key: 'F[0].P5[0].ExposedToTheFollowing[1]'
        },
        'exposureToRadiation' => {
          key: 'F[0].P5[0].ExposedToTheFollowing[2]'
        },
        'exposureToShad' => {
          key: 'F[0].P5[0].ExposedToTheFollowing[3]'
        },
        'exposureToOccupationalHazards' => {
          key: 'F[0].P5[0].ExposedToTheFollowing[4]'
        },
        'exposureToAsbestos' => {
          key: 'F[0].P5[0].ExposedToTheFollowing[5]'
        },
        'exposureToMustardGas' => {
          key: 'F[0].P5[0].ExposedToTheFollowing[6]'
        },
        'exposureToContaminatedWater' => {
          key: 'F[0].P5[0].ExposedToTheFollowing[7]'
        },
        'exposureToWarfareAgents' => {
          key: 'F[0].P5[0].ExposedToTheFollowing[8]'
        },
        'exposureToOther' => {
          key: 'F[0].P5[0].ExposedToTheFollowing[9]'
        },
        'otherToxicExposure' => {
          key: 'F[0].P5[0].SpecifyOther[0]'
        },
        'toxicExposureStartDate' => {
          key: 'F[0].P5[0].FromDate_3D[0]'
        },
        'toxicExposureEndDate' => {
          key: 'F[0].P5[0].ToDate_3D[0]'
        },
        'isMedicaidEligible' => {
          key: 'F[0].P5[0].EligibleForMedicaid[0]'
        },
        'isEnrolledMedicarePartA' => {
          key: 'F[0].P5[0].EnrolledInMedicareHospitalInsurance[0]'
        },
        'providers' =>
          {
            limit: 1,
            first_key: 'insuranceName',
            'insuranceName' => {
              key: 'F[0].P5[0].HealthInsuranceInformation[0]',
              question_num: 3.1,
              question_text: 'ENTER YOUR HEALTH INSURANCE COMPANY NAME, ADDRESS AND TELEPHONE NUMBER'
            },
            'insurancePolicyHolderName' => {
              key: 'F[0].P5[0].NameOfPolicyHodler[0]',
              question_num: 3.2,
              question_text: 'NAME OF POLICY HOLDER'
            },
            'insurancePolicyNumber' => {
              key: 'F[0].P5[0].PolicyNumber[0]',
              question_num: 3.3,
              question_text: 'POLICY NUMBER'
            },
            'insuranceGroupCode' => {
              key: 'F[0].P5[0].GroupCode[0]',
              question_num: 3.4,
              question_text: 'Group Code'
            }
          },
        'dependents' =>
        {
          limit: 1,
          first_key: 'fullName',
          'fullName' => {
            key: 'F[0].P5[0].ChildsName[0]',
            limit: 42,
            question_num: 4.2,
            question_text: 'CHILD\'S NAME (Last, First, Middle Name)'
          },
          'dateOfBirth' => {
            key: 'F[0].P5[0].ChildsDOB[0]',
            question_num: 4.2,
            question_suffix: 'A',
            question_text: 'CHILD\'S DATE OF BIRTH'
          },
          'socialSecurityNumber' => {
            key: 'F[0].P5[0].ChildsSSN[0]',
            question_num: 4.2,
            question_suffix: 'B',
            question_text: 'CHILD\'S Social Security NO.'
          },
          'becameDependent' => {
            key: 'F[0].P5[0].DateChildBecameYourDependent[0]',
            question_num: 4.2,
            question_suffix: 'C',
            question_text: 'DATE CHILD BECAME YOU\'RE DEPENDENT'
          },
          'dependentRelation' => {
            key: 'F[0].P5[0].RelationshipToYou[0]',
            question_num: 4.2,
            question_suffix: 'D',
            question_text: 'CHILD\'S RELATIONSHIP TO YOU'
          },
          'disabledBefore18' => {
            key: 'F[0].P5[0].ChildPermanentlyDiasbledBefore18[0]',
            question_num: 4.2,
            question_suffix: 'E',
            question_text: 'WAS CHILD PERMANENTLY AND TOTALLY DISABLED BEFORE THE AGE OF 18?'
          },
          'attendedSchoolLastYear' => {
            key: 'F[0].P5[0].DidChildAttendSchooLastYear[0]',
            question_num: 4.2,
            question_suffix: 'F',
            question_text: 'IF CHILD IS BETWEEN 18 AND 21 YEARS OF AGE, DID CHILD ATTEND SCHOOL LAST CALENDAR YEAR'
          },
          'dependentEducationExpenses' => {
            key: 'F[0].P5[0].ExpensesPaifByDependentCHild[0]',
            question_num: 4.2,
            question_suffix: 'G',
            question_text: 'EXPENSES PAID BY YOUR DEPENDENT CHILD WITH REPORTABLE INCOME FOR COLLEGE, VOCATIONAL' \
                           ' REHABILITATION OR TRAINING (e.g., tuition, books, materials) '
          },
          'grossIncome' => {
            key: 'F[0].P6[0].Section7_Child_Q1[0]',
            question_num: 7.1,
            question_text: 'DEPENDENT - GROSS ANNUAL INCOME FROM EMPLOYMENT'
          },
          'netIncome' => {
            key: 'F[0].P6[0].Section7_Child_Q2[0]',
            question_num: 7.2,
            question_text: 'DEPENDENT - NET INCOME FROM YOUR FARM, RANCH, PROPERTY OR BUSINESS'
          },
          'otherIncome' => {
            key: 'F[0].P6[0].Section7_Child_Q3[0]',
            question_num: 7.3,
            question_text: 'DEPENDENT - LIST OTHER INCOME AMOUNTS'
          }
        },
        'spouseFullName' => {
          key: 'F[0].P5[0].SpousesName[0]',
          limit: 42,
          question_num: 4.1,
          question_text: "SPOUSE'S NAME (Last, First, Middle Name)"
        },
        'spouseAddress' => {
          key: 'F[0].P5[0].SpouseAddressAndTelephoneNumber[0]',
          limit: 120,
          question_num: 4.1,
          question_suffix: 'E',
          question_text: "SPOUSE'S ADDRESS AND TELEPHONE NUMBER (Street, City, State, ZIP if different from Veteran's)"
        },
        'cohabitedLastYear' => {
          key: 'F[0].P5[0].RadioButtonList[2]'
        },
        'veteranDateOfBirth' => {
          key: 'F[0].P4[0].DOB[0]'
        },
        'lastEntryDate' => {
          key: 'F[0].P4[0].LastEntryDate[0]'
        },
        'lastDischargeDate' => {
          key: 'F[0].P4[0].LastDischargeDate[0]'
        },
        'medicarePartAEffectiveDate' => {
          key: 'F[0].P5[0].EffectiveDate[0]'
        },
        'spouseSocialSecurityNumber' => {
          key: 'F[0].P5[0].SpousesSSN[0]'
        },
        'spouseDateOfBirth' => {
          key: 'F[0].P5[0].SpousesDOB[0]'
        },
        'dateOfMarriage' => {
          key: 'F[0].P5[0].DateOfMarriage[0]'
        },
        'provideSupportLastYear' => {
          key: 'F[0].P5[0].DidYouProvideSupportToChildNotLivingWithYou[0]'
        },
        'discloseFinancialInformation' => {
          key: 'F[0].P6[0].Section6[0]'
        },
        'veteranSocialSecurityNumber' => {
          key: 'F[0].P4[0].SSN[0]'
        },
        'lastServiceBranch' => {
          key: 'F[0].P4[0].LastBranchOfService[0]'
        },
        'dischargeType' => {
          key: 'F[0].P4[0].DischargeType[0]'
        },
        'medicareClaimNumber' => {
          key: 'F[0].P5[0].MedicareClaimNumber[0]'
        },
        'spouseGrossIncome' => {
          key: 'F[0].P6[0].Section7_Spouse_Q1[0]'
        },
        'spouseNetIncome' => {
          key: 'F[0].P6[0].Section7_Spouse_Q2[0]'
        },
        'spouseOtherIncome' => {
          key: 'F[0].P6[0].Section7_Spouse_Q3[0]'
        },
        'veteranGrossIncome' => {
          key: 'F[0].P6[0].Section7_Veteran_Q1[0]'
        },
        'veteranNetIncome' => {
          key: 'F[0].P6[0].Section7_Veteran_Q2[0]'
        },
        'veteranOtherIncome' => {
          key: 'F[0].P6[0].Section7_Veteran_Q3[0]'
        },
        'deductibleMedicalExpenses' => {
          key: 'F[0].P6[0].Section8_Q1[0]'
        },
        'deductibleFuneralExpenses' => {
          key: 'F[0].P6[0].Section8_Q2[0]'
        },
        'deductibleEducationExpenses' => {
          key: 'F[0].P6[0].Section8_Q3[0]'
        }
      }.freeze

      # Merge Fields - This method orchestrates the calling of all merge helper methods to
      # process and populate @form_data with the necessary values for the PDF.
      def merge_fields(_options = {})
        merge_veteran_info
        merge_spouse_info
        merge_healthcare_info
        merge_dependents
        merge_veteran_service_info
        merge_disclose_financial_info
        merge_date_fields

        @form_data
      end

      private

      # Merge helpers - These methods update @form_data with the required values, data types,
      # or formatted values that the PDF fields expect. Each method processes form data,
      # formats or maps the data appropriately, and assigns the result back to @form_data,
      # ensuring it is in the expected format for PDF generation.

      def merge_veteran_info
        merge_full_name('veteranFullName')
        merge_sex('gender')
        merge_place_of_birth
        merge_ethnicity_choices
        merge_marital_status
        merge_value('isSpanishHispanicLatino', :map_radio_box_value)
        merge_address_street('veteranAddress')
        merge_address_street('veteranHomeAddress')
      end

      def merge_spouse_info
        merge_full_name('spouseFullName')
        merge_spouse_address_phone_number
      end

      def merge_healthcare_info
        merge_value('wantsInitialVaContact', :map_radio_box_value)
        merge_value('isMedicaidEligible', :map_radio_box_value)
        merge_value('isEnrolledMedicarePartA', :map_radio_box_value)
      end

      def merge_veteran_service_info
        merge_exposure
        merge_military_service
        merge_tera
        merge_service_connected_rating
      end

      def merge_full_name(type)
        @form_data[type] = FORMATTER.format_full_name(@form_data[type])
      end

      def merge_address_street(address_type)
        return unless @form_data[address_type]

        address = @form_data[address_type]
        @form_data[address_type]['street'] = combine_full_address(
          {
            'street' => address['street'],
            'street2' => address['street2'],
            'street3' => address['street3']
          }
        )
      end

      def merge_sex(type)
        value = SEX[@form_data[type]]
        if value.nil?
          Rails.logger.error('Invalid sex value when filling out 10-10EZ pdf.',
                             { type:, value: @form_data[type] })
        end

        @form_data[type] = value
      end

      def merge_date_fields
        DATE_FIELDS.each do |field|
          merge_value(field, :format_date)
        end
      end

      def merge_marital_status
        @form_data['maritalStatus'] = MARITAL_STATUS[@form_data['maritalStatus']] || OFF
      end

      def merge_place_of_birth
        @form_data['placeOfBirth'] =
          combine_full_address({
                                 'city' => @form_data['cityOfBirth'],
                                 'state' => @form_data['stateOfBirth']
                               })
      end

      def merge_ethnicity_choices
        ETHNICITY_MAP.each do |key, value|
          @form_data[key] = map_value_for_checkbox(@form_data[key], value)
        end
      end

      def merge_service_connected_rating
        @form_data['vaCompensationType'] = DISABILITY_STATUS.find do |keys, _|
          keys.include?(@form_data['vaCompensationType'])
        end&.last
      end

      def merge_exposure
        EXPOSURE_MAP.each do |key, value|
          @form_data[key] = map_value_for_checkbox(@form_data[key], value)
        end
      end

      def merge_spouse_address_phone_number
        spouse_phone = @form_data['spousePhone']
        @form_data['spouseAddress'] = "#{combine_full_address(@form_data['spouseAddress'])} #{spouse_phone}"
      end

      def merge_tera
        merge_value('radiationCleanupEfforts', :map_check_box)
        merge_value('gulfWarService', :map_check_box)
        merge_value('combatOperationService', :map_check_box)
        merge_value('exposedToAgentOrange', :map_check_box)
      end

      def merge_military_service
        merge_value('purpleHeartRecipient', :map_check_box)
        merge_value('isFormerPow', :map_check_box)
        merge_value('postNov111998Combat', :map_check_box)
        merge_value('disabledInLineOfDuty', :map_check_box)
        merge_value('swAsiaCombat', :map_check_box)
      end

      def merge_disclose_financial_info
        @form_data['discloseFinancialInformation'] =
          DISCLOSE_FINANCIAL_INFORMATION[@form_data['discloseFinancialInformation']] || OFF
      end

      def merge_dependents
        merge_value('provideSupportLastYear', :map_radio_box_value)

        return if @form_data['dependents'].blank?

        if @form_data['dependents'].count == 1
          # Format dependent data for pdf field inputs since only one will be rendered
          merge_single_dependent
        else
          # Format dependent data for additional page since when there are more than one dependents
          # we display them all on the additional info section
          merge_multiple_dependents
        end
      end

      def merge_single_dependent
        dependent = @form_data['dependents'].first

        dependent['fullName'] = FORMATTER.format_full_name(dependent['fullName'])
        dependent['dateOfBirth'] = FORMATTER.format_date(dependent['dateOfBirth'])
        dependent['becameDependent'] = FORMATTER.format_date(dependent['becameDependent'])

        dependent['dependentRelation'] = DEPENDENT_RELATIONSHIP[(dependent['dependentRelation'])] || OFF
        dependent['attendedSchoolLastYear'] = map_radio_box_value(dependent['attendedSchoolLastYear'])
        dependent['disabledBefore18'] = map_radio_box_value(dependent['disabledBefore18'])
        dependent['cohabitedLastYear'] = map_radio_box_value(dependent['cohabitedLastYear'])
      end

      def merge_multiple_dependents
        @form_data['dependents'].each do |dependent|
          dependent['fullName'] = FORMATTER.format_full_name(dependent['fullName'])
          dependent['dateOfBirth'] = FORMATTER.format_date(dependent['dateOfBirth'])
          dependent['becameDependent'] = FORMATTER.format_date(dependent['becameDependent'])

          dependent['dependentEducationExpenses'] = FORMATTER.format_currency(dependent['dependentEducationExpenses'])
          dependent['grossIncome'] = FORMATTER.format_currency(dependent['grossIncome'])
          dependent['netIncome'] = FORMATTER.format_currency(dependent['netIncome'])
          dependent['otherIncome'] = FORMATTER.format_currency(dependent['otherIncome'])
        end
      end

      def merge_value(type, method_name)
        @form_data[type] = method(method_name).call(@form_data[type])
      end

      # Map helpers - These methods transform input values into the expected format required for PDF fields
      # They **do not modify** the @form_data but return the corresponding mapped value.

      # Converts a boolean input to the corresponding mapped value for checkboxes.
      def map_value_for_checkbox(input, value)
        input == true ? value : OFF
      end

      # Maps a boolean value to an integer for radio button selection (1 for true, 2 for false, or 'OFF' if undefined).
      def map_radio_box_value(value)
        case value
        when true
          1
        when false
          2
        else
          OFF
        end
      end

      # Maps a boolean value to a 'YES' or 'NO' for checkbox fields.
      def map_check_box(value)
        case value
        when true
          'YES'
        when false
          'NO'
        else
          OFF
        end
      end

      def format_date(value)
        FORMATTER.format_date(value)
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
