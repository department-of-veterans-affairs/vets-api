# frozen_string_literal: true

module PdfFill
  module Forms
    module FieldMappings
      class Va1010ez
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
            key: 'F[0].P5[0].SpecifyOther[0]',
            limit: 20,
            question_num: 2.3,
            question_suffix: 'E',
            question_text: 'HAVE YOU BEEN EXPOSED TO ANY OF THE FOLLOWING? (Check all that apply) - OTHER'
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
            question_text: "SPOUSE'S ADDRESS AND TELEPHONE NUMBER " \
                           "(Street, City, State, ZIP if different from Veteran's)"
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
      end
    end
  end
end
