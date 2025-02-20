# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
# rubocop:disable Metrics/ClassLength
module PdfFill
  module Forms
    class Va1010ez < FormBase
      FORM_ID = HealthCareApplication::FORM_ID
      OFF = 'Off'

      # TODO: These are also in HCA::EnrollmentEligibility::Service. Can we DRY it up?
      MARITAL_STATUS = {
        'Married' => '1',
        'Never Married' => '2',
        'Separated' => '3',
        'Widowed' => '4',
        'Divorced' => '5'
      }.freeze

      DEPENDENT_RELATIONSHIP = {
        'Son' => '1',
        'Daughter' => '2',
        'Stepson' => '3',
        'Stepdaughter' => '4'
      }.freeze

      DISABILITY_STATUS = {
        %w[highDisability lowDisability] => 'YES',
        %w[none] => 'NO'
      }.freeze

      SEX = {
        'M' => '1',
        'F' => '2'
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

      # exposure values correspond to true for each key in the pdf options
      EXPOSURE_MAP = {
        'exposureToAirPollutants' => '1',
        'exposureToChemicals' => '2',
        'exposureToRadiation' => '3',
        'exposureToShad' => '4',
        'exposureToOccupationalHazards' => '5',
        'exposureToAsbestos' => '5',
        'exposureToMustardGas' => '5',
        'exposureToContaminatedWater' => '6',
        'exposureToWarfareAgents' => '6',
        'exposureToOther' => '7'
      }.freeze

      ETHNICITY_MAP = {
        'isAsian' => '1',
        'isAmericanIndianOrAlaskanNative' => '2',
        'isBlackOrAfricanAmerican' => '3',
        'isWhite' => '4',
        'isNativeHawaiianOrOtherPacificIslander' => '5',
        'hasDemographicNoAnswer' => '6'
      }.freeze

      KEY = {
        'veteranFullName' => {
          key: 'F[0].P4[0].LastFirstMiddle[0]'
        },
        'mothersMaidenName' => {
          key: 'F[0].P4[0].MothersMaidenName[0]'
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
          key: 'F[0].P4[0].PlaceOfBirth[0]'
        },
        'veteranAddress' =>
          {
            'street' => {
              key: 'F[0].P4[0].MailingAddress_Street[0]'
            },
            'city' => {
              key: 'F[0].P4[0].MailingAddress_City[0]'
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
              key: 'F[0].P4[0].HomeAddress_Street[0]'
            },
            'city' => {
              key: 'F[0].P4[0].HomeAddress_City[0]'
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
            'insuranceName' => {
              key: 'F[0].P5[0].HealthInsuranceInformation[0]'
            },
            'insurancePolicyHolderName' => {
              key: 'F[0].P5[0].NameOfPolicyHodler[0]'
            },
            'insurancePolicyNumber' => {
              key: 'F[0].P5[0].PolicyNumber[0]'
            },
            'insuranceGroupCode' => {
              key: 'F[0].P5[0].GroupCode[0]'
            }
          },
        'dependents' =>
          {
            'fullName' => {
              key: 'F[0].P5[0].ChildsName[0]'
            },
            'dependentRelation' => {
              key: 'F[0].P5[0].RelationshipToYou[0]'
            },
            'socialSecurityNumber' => {
              key: 'F[0].P5[0].ChildsSSN[0]'
            },
            'dateOfBirth' => {
              key: 'F[0].P5[0].ChildsDOB[0]'
            },
            'becameDependent' => {
              key: 'F[0].P5[0].DateChildBecameYourDependent[0]'
            },
            'attendedSchoolLastYear' => {
              key: 'F[0].P5[0].DidChildAttendSchooLastYear[0]'
            },
            'disabledBefore18' => {
              key: 'F[0].P5[0].ChildPermanentlyDiasbledBefore18[0]'
            },
            'dependentEducationExpenses' => {
              key: 'F[0].P5[0].ExpensesPaifByDependentCHild[0]'
            },
            'grossIncome' => {
              key: 'F[0].P6[0].Section7_Child_Q1[0]'
            },
            'netIncome' => {
              key: 'F[0].P6[0].Section7_Child_Q2[0]'
            },
            'otherIncome' => {
              key: 'F[0].P6[0].Section7_Child_Q3[0]'
            }
          },
        'spouseFullName' => {
          key: 'F[0].P5[0].SpousesName[0]'
        },
        'spouseAddress' => {
          key: 'F[0].P5[0].SpouseAddressAndTelephoneNumber[0]'
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

      def merge_fields(_options = {})
        merge_full_name('veteranFullName')
        merge_full_name('spouseFullName')
        merge_sex('gender')
        merge_place_of_birth
        merge_ethnicity_choices
        merge_marital_status
        merge_spouse_address_phone_number
        @form_data['provideSupportLastYear'] = map_radio_box_value(@form_data['provideSupportLastYear'])
        @form_data['isSpanishHispanicLatino'] = map_radio_box_value(@form_data['isSpanishHispanicLatino'])
        @form_data['wantsInitialVaContact'] = map_radio_box_value(@form_data['wantsInitialVaContact'])
        @form_data['isMedicaidEligible'] = map_radio_box_value(@form_data['isMedicaidEligible'])
        @form_data['isEnrolledMedicarePartA'] = map_radio_box_value(@form_data['isEnrolledMedicarePartA'])
        merge_exposure
        merge_military_service
        merge_providers
        merge_dependents
        merge_tera
        merge_disclose_financial_info
        merge_service_connected_rating
        @form_data
      end

      private

      def merge_full_name(type)
        @form_data[type] = combine_full_name(@form_data[type])
      end

      def merge_sex(type)
        value = SEX[@form_data[type]]
        if value.nil?
          Rails.logger.error('Invalid sex value when filling out 10-10EZ pdf.',
                             { type:, value: @form_data[type] })
        end

        @form_data[type] = value
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
        merge_yes_no('radiationCleanupEfforts')
        merge_yes_no('gulfWarService')
        merge_yes_no('combatOperationService')
        merge_yes_no('exposedToAgentOrange')
      end

      def merge_military_service
        merge_yes_no('purpleHeartRecipient')
        merge_yes_no('isFormerPow')
        merge_yes_no('postNov111998Combat')
        merge_yes_no('disabledInLineOfDuty')
        merge_yes_no('swAsiaCombat')
      end

      def merge_yes_no(type)
        @form_data[type] = map_check_box(@form_data[type])
      end

      def merge_providers
        # TODO: Support more than one provider - planned work https://github.com/department-of-veterans-affairs/va.gov-team/issues/102910
        providers = @form_data['providers']
        return unless providers.is_a?(Array) && providers.any?

        @form_data['providers'] = providers.first
      end

      def merge_disclose_financial_info
        @form_data['discloseFinancialInformation'] =
          DISCLOSE_FINANCIAL_INFORMATION[@form_data['discloseFinancialInformation']] || OFF
      end

      def merge_dependents
        # TODO: Support more than one dependent - planned work https://github.com/department-of-veterans-affairs/va.gov-team/issues/102890
        dependents = @form_data['dependents']
        return if dependents.blank?

        dependent = dependents.first
        dependent['fullName'] = combine_full_name(dependent['fullName'])
        dependent['dependentRelation'] = DEPENDENT_RELATIONSHIP[(dependent['dependentRelation'])] || OFF
        dependent['attendedSchoolLastYear'] = map_radio_box_value(dependent['attendedSchoolLastYear'])
        dependent['disabledBefore18'] = map_radio_box_value(dependent['disabledBefore18'])
        dependent['cohabitedLastYear'] = map_radio_box_value(dependent['cohabitedLastYear'])
        @form_data['dependents'] = dependent
      end

      def map_value_for_checkbox(input, value)
        input == true ? value : OFF
      end

      def map_radio_box_value(value)
        case value
        when true
          '1'
        when false
          '2'
        else
          OFF
        end
      end

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
    end
  end
end
# rubocop:enable Metrics/ClassLength
