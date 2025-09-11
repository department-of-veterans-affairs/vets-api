# frozen_string_literal: true

module PdfFill
  module Forms
    module FieldMappings
      class Va1010ezr
        KEY = {
          'veteranFullName' => {
            key: ['F[0].P3[0].VeteransName[0]', 'F[0].P4[0].VeteransName[0]', 'F[0].P5[0].VeteransName[0]'],
            limit: 40,
            question_num: 1.01,
            question_suffix: 'A',
            question_text: "VETERAN'S NAME (Last, First, Middle Name)"
          },
          'veteranSocialSecurityNumber' => {
            key: ['F[0].P3[0].VeteranSSN[0]', 'F[0].P4[0].VeteranSSN[0]', 'F[0].P5[0].VeteranSSN[0]']
          },
          'gender' => {
            key: 'F[0].P3[0].Sex[0]'
          },
          'veteranDateOfBirth' => {
            key: 'F[0].P3[0].DateofBirth[0]'
          },
          'homePhone' => {
            key: 'F[0].P3[0].HomePhone[0]'
          },
          'mobilePhone' => {
            key: 'F[0].P3[0].MobilePhone[0]'
          },
          'veteranAddress' => {
            'street' => {
              key: 'F[0].P3[0].MailingAddress_Street[0]',
              limit: 27,
              question_num: 1.06,
              question_suffix: 'A',
              question_text: 'MAILING ADDRESS - STREET'
            },
            'city' => {
              key: 'F[0].P3[0].MailingAddress_City[0]',
              limit: 18,
              question_num: 1.06,
              question_suffix: 'B',
              question_text: 'MAILING ADDRESS - CITY'
            },
            'state' => {
              key: 'F[0].P3[0].MailingAddress_State[0]'
            },
            'postalCode' => {
              key: 'F[0].P3[0].MailingAddress_ZipCode[0]'
            }
          },
          'veteranHomeAddress' => {
            'street' => {
              key: 'F[0].P3[0].Street[0]',
              limit: 27,
              question_num: 1.07,
              question_suffix: 'A',
              question_text: 'HOME ADDRESS - STREET'
            },
            'city' => {
              key: 'F[0].P3[0].City[0]',
              limit: 18,
              question_num: 1.07,
              question_suffix: 'B',
              question_text: 'HOME ADDRESS - CITY'
            },
            'state' => {
              key: 'F[0].P3[0].State[0]'
            },
            'postalCode' => {
              key: 'F[0].P3[0].ZipCode[0]'
            }
          },
          'email' => {
            key: 'F[0].P3[0].Email[0]',
            limit: 50
          },
          'maritalStatus' => {
            key: 'F[0].P3[0].MaritalStatus[0]'
          },
          'nextOfKins' => {
            limit: 1,
            first_key: 'fullName',
            'fullName' => {
              key: 'F[0].P3[0].KinName[0]',
              limit: 38,
              question_num: 1.10,
              question_suffix: 'A',
              question_text: 'NEXT OF KIN NAME (Last, First, Middle Name).'
            },
            'address' => {
              limit: 48,
              key: 'F[0].P3[0].KinAddress[0]',
              question_num: 1.10,
              question_suffix: 'B',
              question_text: 'NEXT OF KIN ADDRESS.'
            },
            'relationship' => {
              question_num: 1.10,
              question_suffix: 'C',
              question_text: 'NEXT OF KIN RELATIONSHIP',
              key: 'F[0].P3[0].KinRelationship[0]'
            },
            'primaryPhone' => {
              question_num: 1.10,
              question_suffix: 'D',
              question_text: 'NEXT OF KIN TELEPHONE NUMBER',
              key: 'F[0].P3[0].KinPhone[0]'
            }
          },
          'emergencyContacts' => {
            limit: 1,
            first_key: 'fullName',
            'fullName' => {
              key: 'F[0].P3[0].ECName[0]',
              limit: 38,
              question_num: 1.11,
              question_suffix: 'A',
              question_text: 'EMERGENCY CONTACT NAME.'
            },
            'primaryPhone' => {
              question_num: 1.11,
              question_suffix: 'B',
              key: 'F[0].P3[0].ECPhone[0]',
              question_text: 'EMERGENCY CONTACT TELEPHONE NUMBER.'
            },
            'address' => {
              limit: 1,
              question_num: 1.11,
              question_suffix: 'C',
              question_text: 'EMERGENCY CONTACT ADDRESS.'
            }
          },
          'providers' => {
            limit: 1,
            first_key: 'insuranceName',
            'insuranceName' => {
              key: 'F[0].P3[0].HealthInsurance[0]',
              question_num: 2.1,
              question_text: 'ENTER YOUR HEALTH INSURANCE COMPANY NAME, ADDRESS AND TELEPHONE NUMBER.'
            },
            'insurancePolicyHolderName' => {
              key: 'F[0].P3[0].NamePolicyHolder[0]',
              question_num: 2.2,
              question_text: 'NAME OF POLICY HOLDER.',
              limit: 25
            },
            'insurancePolicyNumber' => {
              key: 'F[0].P3[0].PolicyNo[0]',
              question_num: 2.3,
              question_text: 'POLICY NUMBER.'
            },
            'insuranceGroupCode' => {
              key: 'F[0].P3[0].GroupCode[0]',
              question_num: 2.4,
              question_text: 'GROUP CODE.'
            }
          },
          'isMedicaidEligible' => {
            key: 'F[0].P3[0].EligibleForMedicaid[0]'
          },
          'isEnrolledMedicarePartA' => {
            key: 'F[0].P3[0].EnrolledInMedicareHospitalInsurance[0]'
          },
          'medicarePartAEffectiveDate' => {
            key: 'F[0].P3[0].EffectiveDate[0]'
          },
          'medicareClaimNumber' => {
            key: 'F[0].P3[0].MedicareClaimNumber[0]'
          },
          'radiationCleanupEfforts' => {
            key: 'F[0].P4[0].Section3_3A[0]'
          },
          'gulfWarService' => {
            key: 'F[0].P4[0].Section3_3B[0]'
          },
          'gulfWarStartDate' => {
            key: 'F[0].P4[0].FromDate_3B[0]'
          },
          'gulfWarEndDate' => {
            key: 'F[0].P4[0].ToDate_3B[0]'
          },
          'combatOperationService' => {
            key: 'F[0].P4[0].Section3_3B[1]'
          },
          'exposedToAgentOrange' => {
            key: 'F[0].P4[0].Section3_3C[0]'
          },
          'agentOrangeStartDate' => {
            key: 'F[0].P4[0].FromDate_3C[0]'
          },
          'agentOrangeEndDate' => {
            key: 'F[0].P4[0].ToDate_3C[0]'
          },
          'exposureToAirPollutants' => {
            key: 'F[0].P4[0].ExposedToTheFollowing[0]'
          },
          'exposureToChemicals' => {
            key: 'F[0].P4[0].ExposedToTheFollowing[1]'
          },
          'exposureToContaminatedWater' => {
            key: 'F[0].P4[0].ExposedToTheFollowing[2]'
          },
          'exposureToRadiation' => {
            key: 'F[0].P4[0].ExposedToTheFollowing[3]'
          },
          'exposureToShad' => {
            key: 'F[0].P4[0].ExposedToTheFollowing[4]'
          },
          'exposureToOccupationalHazards' => {
            key: 'F[0].P4[0].ExposedToTheFollowing[5]'
          },
          'exposureToAsbestos' => {
            key: 'F[0].P4[0].ExposedToTheFollowing[6]'
          },
          'exposureToMustardGas' => {
            key: 'F[0].P4[0].ExposedToTheFollowing[7]'
          },
          'exposureToWarfareAgents' => {
            key: 'F[0].P4[0].ExposedToTheFollowing[8]'
          },
          'exposureToOther' => {
            key: 'F[0].P4[0].ExposedToTheFollowing[9]'
          },
          'otherToxicExposure' => {
            key: 'F[0].P4[0].SpecifyOther[0]',
            limit: 30,
            question_num: 3.3,
            question_suffix: 'E',
            question_text: 'Specify Other.'
          },
          'toxicExposureStartDate' => {
            key: 'F[0].P4[0].FromDate_3D[0]'
          },
          'toxicExposureEndDate' => {
            key: 'F[0].P4[0].ToDate_3D[0]'
          },
          'spouseFullName' => {
            key: 'F[0].P4[0].SpouseName[0]',
            limit: 40,
            question_num: 4.01,
            question_text: "SPOUSE'S NAME (Last, First, Middle Name)"
          },
          'spouseSocialSecurityNumber' => {
            key: 'F[0].P4[0].SpouseSSN[0]'
          },
          'spouseDateOfBirth' => {
            key: 'F[0].P4[0].SpouseDateofBirth[0]'
          },
          'dateOfMarriage' => {
            key: 'F[0].P4[0].DateofMarriage[0]'
          },
          'spouseAddress' => {
            key: 'F[0].P4[0].SpouseAddress[0]',
            limit: 120,
            question_num: 4.06,
            question_text: "SPOUSE'S ADDRESS AND TELEPHONE NUMBER (Street, City, State, " \
                           "ZIP - if different from Veteran's)"
          },
          'dependents' => {
            limit: 1,
            first_key: 'fullName',
            'fullName' => {
              key: 'F[0].P4[0].ChildName[0]',
              limit: 42,
              question_num: 4.07,
              question_text: 'NAME (Last, First, Middle Name).'
            },
            'dateOfBirth' => {
              key: 'F[0].P4[0].ChildDateofBirth[0]',
              question_num: 4.08,
              question_text: 'DATE OF BIRTH.'
            },
            'socialSecurityNumber' => {
              key: 'F[0].P4[0].ChildSSN[0]',
              question_num: 4.09,
              question_text: 'SOCIAL SECURITY NUMBER.'
            },
            'becameDependent' => {
              key: 'F[0].P4[0].DateDependent[0]',
              question_num: 4.10,
              question_text: 'DATE BECAME YOUR DEPENDENT.'
            },
            'dependentRelation' => {
              key: 'F[0].P4[0].Relationship[0]',
              question_num: 4.11
            },
            'disabledBefore18' => {
              key: 'F[0].P4[0].YesNo3[0]',
              question_num: 4.12
            },
            'attendedSchoolLastYear' => {
              key: 'F[0].P4[0].YesNo4[0]',
              question_num: 4.13
            },
            'dependentEducationExpenses' => {
              key: 'F[0].P4[0].TextField22[0]',
              question_num: 4.14,
              question_text: 'EXPENSES PAID BY YOUR DEPENDENT CHILD WITH REPORTABLE INCOME FOR COLLEGE, ' \
                             'VOCATIONAL REHABILITATION OR TRAINING (e.g., tuition, books, materials). '
            },
            'receivedSupportLastYear' => {
              question_num: 5.1,
              question_text: 'IF YOUR DEPENDENT DID NOT LIVE WITH YOU LAST YEAR, DID YOU PROVIDE SUPPORT?'
            },
            'grossIncome' => {
              key: 'F[0].P5[0].Table1[0].#subform[1].Amount[2]',
              question_num: 5.1,
              question_text: 'GROSS ANNUAL INCOME. Enter dollar amount.'
            },
            'netIncome' => {
              key: 'F[0].P5[0].Table1[0].#subform[2].Amount[5]',
              question_num: 5.2,
              question_text: 'NET INCOME. Enter dollar amount.'
            },
            'otherIncome' => {
              key: 'F[0].P5[0].Table1[0].#subform[3].Amount[8]',
              question_num: 5.3,
              question_text: 'OTHER INCOME. Enter dollar amount.'
            }
          },
          'provideSupportLastYear' => {
            key: 'F[0].P4[0].YesNo5[0]'
          },
          'veteranGrossIncome' => {
            key: 'F[0].P5[0].Table1[0].#subform[1].Amount[0]'
          },
          'spouseGrossIncome' => {
            key: 'F[0].P5[0].Table1[0].#subform[1].Amount[1]'
          },
          'veteranNetIncome' => {
            key: 'F[0].P5[0].Table1[0].#subform[2].Amount[3]'
          },
          'spouseNetIncome' => {
            key: 'F[0].P5[0].Table1[0].#subform[2].Amount[4]'
          },
          'veteranOtherIncome' => {
            key: 'F[0].P5[0].Table1[0].#subform[3].Amount[6]'
          },
          'spouseOtherIncome' => {
            key: 'F[0].P5[0].Table1[0].#subform[3].Amount[7]'
          },
          'deductibleMedicalExpenses' => {
            key: 'F[0].P5[0].Amount[0]'
          },
          'deductibleFuneralExpenses' => {
            key: 'F[0].P5[0].Amount[1]'
          },
          'deductibleEducationExpenses' => {
            key: 'F[0].P5[0].Amount[2]'
          }
        }.freeze
      end
    end
  end
end
