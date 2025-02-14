# frozen_string_literal: true

require 'pdf_fill/forms/form_base'

module PdfFill
  module Forms
    class Va1010ez < FormBase
      FORM_ID = HealthCareApplication::FORM_ID

      KEY = {
        'veteranFullName' => {
          key: 'F[0].P4[0].LastFirstMiddle[0]', question_num: 3
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
          key: 'F[0].P5[0].RadioButtonList[6]'
        },
        'isFormerPow' => {
          key: 'F[0].P5[0].RadioButtonList[7]'
        },
        'postNov111998Combat' => {
          key: 'F[0].P5[0].RadioButtonList[8]'
        },
        'disabledInLineOfDuty' => {
          key: 'F[0].P5[0].RadioButtonList[9]'
        },
        'swAsiaCombat' => {
          key: 'F[0].P5[0].RadioButtonList[10]'
        },
        'vietnamService' => {
          key: 'F[0].P5[0].RadioButtonList[12]'
        },
        'exposedToRadiation' => {
          key: 'F[0].P5[0].RadioButtonList[13]'
        },
        'radiumTreatments' => {
          key: 'F[0].P5[0].RadioButtonList[14]'
        },
        'campLejeune' => {
          key: 'F[0].P5[0].RadioButtonList[15]'
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
              key: 'F[0].P5[0].TextField17[0]'
            },
            'insurancePolicyHolderName' => {
              key: 'F[0].P5[0].TextField18[0]'
            },
            'insurancePolicyNumber' => {
              key: 'F[0].P5[0].TextField19[0]'
            },
            'insuranceGroupCode' => {
              key: 'F[0].P5[0].TextField19[1]'
            }
          },
        'dependents' =>
          {
            'fullName' => {
              key: 'F[0].P5[0].TextField20[1]'
            },
            'dependentRelation' => {
              key: 'F[0].P5[0].RadioButtonList[3]'
            },
            'socialSecurityNumber' => {
              key: 'F[0].P5[0].TextField20[4]'
            },
            'dateOfBirth' => {
              key: 'F[0].P5[0].DateTimeField3[0]'
            },
            'becameDependent' => {
              key: 'F[0].P5[0].DateTimeField7[0]'
            },
            'attendedSchoolLastYear' => {
              key: 'F[0].P5[0].RadioButtonList[1]'
            },
            'disabledBefore18' => {
              key: 'F[0].P5[0].RadioButtonList[0]'
            },
            'grossIncome' => {
              key: 'F[0].P6[0].NumericField2[2]'
            },
            'netIncome' => {
              key: 'F[0].P6[0].NumericField2[5]'
            },
            'otherIncome' => {
              key: 'F[0].P6[0].NumericField2[8]'
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
          key: 'F[0].P5[0].DateTimeField1[0]'
        },
        'spouseDateOfBirth' => {
          key: 'F[0].P5[0].DateTimeField6[0]'
        },
        'dateOfMarriage' => {
          key: 'F[0].P5[0].DateOfMarriage[0]'
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
          key: 'F[0].P6[0].NumericField2[1]'
        },
        'spouseNetIncome' => {
          key: 'F[0].P6[0].NumericField2[4]'
        },
        'spouseOtherIncome' => {
          key: 'F[0].P6[0].NumericField2[7]'
        },
        'veteranGrossIncome' => {
          key: 'F[0].P6[0].NumericField2[0]'
        },
        'veteranNetIncome' => {
          key: 'F[0].P6[0].NumericField2[3]'
        },
        'veteranOtherIncome' => {
          key: 'F[0].P6[0].NumericField2[6]'
        },
        'deductibleMedicalExpenses' => {
          key: 'F[0].P6[0].NumericField2[9]'
        },
        'deductibleFuneralExpenses' => {
          key: 'F[0].P6[0].NumericField2[10]'
        },
        'deductibleEducationExpenses' => {
          key: 'F[0].P6[0].NumericField2[11]'
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
        merge_yes_no('isSpanishHispanicLatino')
        merge_yes_no('wantsInitialVaContact')
        merge_yes_no('isMedicaidEligible')
        merge_yes_no('isEnrolledMedicarePartA')
        @form_data
      end

      private

      def merge_full_name(type)
        @form_data[type] = combine_full_name(@form_data[type])
      end

      def merge_sex(type)
        @form_data[type] = case @form_data[type]
                           when 'M'
                             '1'
                           when 'F'
                             '2'
                           end
      end

      def merge_marital_status
        # TODO: These are also in HCA::EnrollmentEligibility::Service. Can we DRY it up?
        @form_data['maritalStatus'] = case @form_data['maritalStatus']
                                      when 'Married'
                                        '1'
                                      when 'Never Married'
                                        '2'
                                      when 'Separated'
                                        '3'
                                      when 'Widowed'
                                        '4'
                                      when 'Divorced'
                                        '5'
                                      else
                                        'Off'
                                      end
      end

      def merge_place_of_birth
        @form_data['placeOfBirth'] =
          combine_full_address({
                                 'city' => @form_data['cityOfBirth'],
                                 'state' => @form_data['stateOfBirth']
                               })
      end

      def merge_ethnicity_choices
        ethnicity_map = {
          'isAsian' => '1',
          'isAmericanIndianOrAlaskanNative' => '2',
          'isBlackOrAfricanAmerican' => '3',
          'isWhite' => '4',
          'isNativeHawaiianOrOtherPacificIslander' => '5',
          'hasDemographicNoAnswer' => '6'
        }

        ethnicity_map.each do |key, value|
          @form_data[key] = @form_data[key] == true ? value : 'Off'
        end
      end

      def merge_spouse_address_phone_number
        spouse_phone = @form_data['spousePhone']
        @form_data['spouseAddress'] = "#{combine_full_address(@form_data['spouseAddress'])} #{spouse_phone}"
      end

      def merge_yes_no(type)
        @form_data[type] = @form_data[type] == true ? '1' : '2'
      end
    end
  end
end
