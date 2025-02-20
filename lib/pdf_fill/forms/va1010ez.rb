# frozen_string_literal: true

require 'pdf_fill/forms/form_base'

module PdfFill
  module Forms
    class Va1010ez < FormBase
      FORM_ID = HealthCareApplication::FORM_ID

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
        merge_full_name
        @form_data
      end

      private

      def merge_full_name
        @form_data['veteranFullName'] =
          combine_full_name(@form_data['veteranFullName'])
      end
    end
  end
end
