# frozen_string_literal: true

module PdfFill
  module Forms
    module Maps
      module InputMap1010Ez
        def self.extended(base)
          base.include(self)
        end

        INPUT_MAP = OpenStruct.new(
          benefits_type: {
            enrollment: 'F[0].P4[0].CheckBox7[6]',
            registration: 'F[0].P4[0].CheckBox7[7]'
          },
          veteran: {
            name: 'F[0].P4[0].LastFirstMiddle[0]',
            preferred_name: 'F[0].P4[0].TextField2[1]',
            mothers_maiden_name: 'F[0].P4[0].TextField2[0]',
            date_of_birth: 'F[0].P4[0].DateTimeField4[0]',
            gender: 'F[0].P4[0].RadioButtonList[1]',
            sigi_genders: 'F[0].P4[0].RadioButtonList[4]',
            ssn: 'F[0].P4[0].SSN[0]',
            place_of_birth: 'F[0].P4[0].TextField5[0]',
            state_of_birth: 'F[0].P4[0].TextField5[0]',
            marital_status: 'F[0].P4[0].RadioButtonList[3]',
            email: 'F[0].P4[0].TextField23[0]',
            home_phone: 'F[0].P4[0].TextField10[0]',
            mobile_phone: 'F[0].P4[0].TextField11[0]',
            initial_va_contact: 'F[0].P4[0].RadioButtonList[2]',
            address: {
              street: 'F[0].P4[0].TextField6[0]',
              city: 'F[0].P4[0].TextField7[0]',
              state: 'F[0].P4[0].TextField8[0]',
              postalCode: 'F[0].P4[0].TextField25[0]'
            },
            home_address: {
              street: 'F[0].P4[0].TextField6[1]',
              city: 'F[0].P4[0].TextField7[1]',
              state: 'F[0].P4[0].TextField8[1]',
              postalCode: 'F[0].P4[0].TextField25[1]'
            },
            ethnicity: {
              isAmericanIndianOrAlaskanNative: 'F[0].P4[0].CheckBox7[0]',
              isAsian: 'F[0].P4[0].CheckBox7[1]',
              isBlackOrAfricanAmerican: 'F[0].P4[0].CheckBox7[3]',
              isSpanishHispanicLatino: 'F[0].P4[0].RadioButtonList[0]',
              isNativeHawaiianOrOtherPacificIslander: 'F[0].P4[0].CheckBox7[4]',
              isWhite: 'F[0].P4[0].CheckBox7[2]',
              hasDemographicNoAnswer: 'F[0].P4[0].CheckBox7[5]'
            },
            service: {
              last_branch_of_service: 'F[0].P5[0].TextField13[0]',
              last_entry_date: 'F[0].P5[0].DateTimeField8[0]',
              last_discharge_date: 'F[0].P5[0].DateTimeField9[0]',
              discharge_type: 'F[0].P5[0].TextField24[0]',
              purple_heart_recipient: 'F[0].P5[0].RadioButtonList[6]',
              is_former_pow: 'F[0].P5[0].RadioButtonList[7]',
              post_11111998_combat: 'F[0].P5[0].RadioButtonList[8]',
              disabled_in_lod: 'F[0].P5[0].RadioButtonList[9]',
              sw_asia_combat: 'F[0].P5[0].RadioButtonList[10]',
              vietnam_service: 'F[0].P5[0].RadioButtonList[12]',
              exposed_to_radiation: 'F[0].P5[0].RadioButtonList[13]',
              radium_treatments: 'F[0].P5[0].RadioButtonList[14]',
              camp_lejeune: 'F[0].P5[0].RadioButtonList[15]'
            },
            disclose_financial_information: 'F[0].P6[0].RadioButtonList[0]',
            gross_income: 'F[0].P6[0].NumericField2[0]',
            net_income: 'F[0].P6[0].NumericField2[3]',
            other_income: 'F[0].P6[0].NumericField2[6]'
          },
          spouse: {
            name: 'F[0].P5[0].TextField20[0]',
            date_of_birth: 'F[0].P5[0].DateTimeField6[0]',
            date_of_marriage: 'F[0].P5[0].DateTimeField5[0]',
            address: 'F[0].P5[0].TextField20[3]',
            cohabitated_last_year: 'F[0].P5[0].RadioButtonList[2]',
            gross_income: 'F[0].P6[0].NumericField2[1]',
            net_income: 'F[0].P6[0].NumericField2[4]',
            other_income: 'F[0].P6[0].NumericField2[7]'
          },
          is_medicaid_eligible: 'F[0].P5[0].RadioButtonList[4]',
          is_enrolled_nedicare_part_a: 'F[0].P5[0].RadioButtonList[5]',
          medicare_number: 'F[0].P5[0].MedicareClaimNumber[0]',
          medicare_effective_date: 'F[0].P5[0].DateTimeField1[0]',
          deductible_medical_expenses: 'F[0].P6[0].NumericField2[9]',
          deductible_funeral_expenses: 'F[0].P6[0].NumericField2[10]',
          deductible_education_expenses: 'F[0].P6[0].NumericField2[11]',
          providers: {
            insurance_name: 'F[0].P5[0].TextField17[0]',
            insurance_policy_holder_name: 'F[0].P5[0].TextField18[0]',
            insurance_policy_number: 'F[0].P5[0].TextField19[0]',
            insurance_group_code: 'F[0].P5[0].TextField19[1]'
          },
          dependents: {
            name: 'F[0].P5[0].TextField20[1]',
            date_of_birth: 'F[0].P5[0].DateTimeField3[0]',
            ssn: 'F[0].P5[0].TextField20[4]',
            relation: 'F[0].P5[0].RadioButtonList[3]',
            became_dependent: 'F[0].P5[0].DateTimeField7[0]',
            attend_school_last_year: 'F[0].P5[0].RadioButtonList[1]',
            disabled_before18: 'F[0].P5[0].RadioButtonList[0]',
            gross_income: 'F[0].P6[0].NumericField2[2]',
            net_income: 'F[0].P6[0].NumericField2[5]',
            other_income: 'F[0].P6[0].NumericField2[8]'
          }
        )
      end
    end
  end
end
