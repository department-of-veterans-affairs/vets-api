# frozen_string_literal: true

require 'pdf_fill/forms/maps/input_map_1010_ez'

module PdfFill
  module Forms
    module Maps
      module KeyMap1010Ez
        extend InputMap1010Ez

        KEY = {
          'helpers' => {
            'veteranFullName' => { key: INPUT_MAP.veteran[:name], question_num: 3 },
            'gender' => { key: INPUT_MAP.veteran[:gender], question_num: 6 },
            'sigiGenders' => { key: INPUT_MAP.veteran[:sigi_genders], question_num: 7 },
            'placeOfBirth' => { key: INPUT_MAP.veteran[:place_of_birth], question_num: 12 },
            'isAmericanIndianOrAlaskanNative' => {
              key: INPUT_MAP.veteran[:ethnicity][:isAmericanIndianOrAlaskanNative],
              question_num: 9
            },
            'isAsian' => { key: INPUT_MAP.veteran[:ethnicity][:isAsian], question_num: 9 },
            'isBlackOrAfricanAmerican' => {
              key: INPUT_MAP.veteran[:ethnicity][:isBlackOrAfricanAmerican],
              question_num: 9
            },
            'isSpanishHispanicLatino' => {
              key: INPUT_MAP.veteran[:ethnicity][:isSpanishHispanicLatino],
              question_num: 8
            },
            'isNativeHawaiianOrOtherPacificIslander' => {
              key: INPUT_MAP.veteran[:ethnicity][:isNativeHawaiianOrOtherPacificIslander],
              question_num: 9
            },
            'isWhite' => { key: INPUT_MAP.veteran[:ethnicity][:isWhite], question_num: 9 },
            'hasDemographicNoAnswer' => {
              key: INPUT_MAP.veteran[:ethnicity][:hasDemographicNoAnswer], question_num: 9
            },
            'maritalStatus' => { key: INPUT_MAP.veteran[:marital_status], question_num: 28 },
            'wantsInitialVaContact' => { key: INPUT_MAP.veteran[:initial_va_contact], question_num: 37 },
            'purpleHeartRecipient' => { key: INPUT_MAP.veteran[:service][:purple_heart_recipient] },
            'isFormerPow' => { key: INPUT_MAP.veteran[:service][:is_former_pow] },
            'postNov111998Combat' => { key: INPUT_MAP.veteran[:service][:post_11111998_combat] },
            'disabledInLineOfDuty' => { key: INPUT_MAP.veteran[:service][:disabled_in_lod] },
            'swAsiaCombat' => { key: INPUT_MAP.veteran[:service][:sw_asia_combat] },
            'vietnamService' => { key: INPUT_MAP.veteran[:service][:vietnam_service] },
            'exposedToRadiation' => { key: INPUT_MAP.veteran[:service][:exposed_to_radiation] },
            'radiumTreatments' => { key: INPUT_MAP.veteran[:service][:radium_treatments] },
            'campLejeune' => { key: INPUT_MAP.veteran[:service][:camp_lejeune] },
            'isMedicaidEligible' => { key: INPUT_MAP.is_medicaid_eligible },
            'isEnrolledMedicarePartA' => { key: INPUT_MAP.is_enrolled_nedicare_part_a },
            'providers' => {
              'insuranceName' => { key: INPUT_MAP.providers[:insurance_name] },
              'insurancePolicyHolderName' => { key: INPUT_MAP.providers[:insurance_policy_holder_name] },
              'insurancePolicyNumber' => { key: INPUT_MAP.providers[:insurance_policy_number] },
              'insuranceGroupCode' => { key: INPUT_MAP.providers[:insurance_group_code] }
            },
            'dependents' => {
              'fullName' => { key: INPUT_MAP.dependents[:name] },
              'dependentRelation' => { key: INPUT_MAP.dependents[:relation] },
              'socialSecurityNumber' => { key: INPUT_MAP.dependents[:ssn] },
              'dateOfBirth' => { key: INPUT_MAP.dependents[:date_of_birth] },
              'becameDependent' => { key: INPUT_MAP.dependents[:became_dependent] },
              'attendedSchoolLastYear' => { key: INPUT_MAP.dependents[:attend_school_last_year] },
              'disabledBefore18' => { key: INPUT_MAP.dependents[:disabled_before18] },
              'grossIncome' => { key: INPUT_MAP.dependents[:gross_income] },
              'netIncome' => { key: INPUT_MAP.dependents[:net_income] },
              'otherIncome' => { key: INPUT_MAP.dependents[:other_income] }
            },
            'spouseFullName' => { key: INPUT_MAP.spouse[:name] },
            'spouseAddress' => { key: INPUT_MAP.spouse[:address] },
            'cohabitedLastYear' => { key: INPUT_MAP.spouse[:cohabitated_last_year] },
            'veteranDateOfBirth' => { key: INPUT_MAP.veteran[:date_of_birth], question_num: 11 },
            'lastEntryDate' => { key: INPUT_MAP.veteran[:service][:last_entry_date] },
            'lastDischargeDate' => { key: INPUT_MAP.veteran[:service][:last_discharge_date] },
            'medicarePartAEffectiveDate' => { key: INPUT_MAP.medicare_effective_date },
            'spouseDateOfBirth' => { key: INPUT_MAP.spouse[:date_of_birth] },
            'dateOfMarriage' => { key: INPUT_MAP.spouse[:date_of_marriage] },
            'discloseFinancialInformation' => { key: INPUT_MAP.veteran[:disclose_financial_information] }
          },
          'mothersMaidenName' => { key: INPUT_MAP.veteran[:mothers_maiden_name], question_num: 5 },
          'veteranSocialSecurityNumber' => { key: INPUT_MAP.veteran[:ssn], question_num: 10 },
          'email' => { key: INPUT_MAP.veteran[:email], question_num: 22 },
          'homePhone' => { key: INPUT_MAP.veteran[:home_phone], question_num: 20 },
          'mobilePhone' => { key: INPUT_MAP.veteran[:mobile_phone], question_num: 21 },
          'veteranAddress' => {
            'street' => { key: INPUT_MAP.veteran[:address][:street], question_num: 15 },
            'city' => { key: INPUT_MAP.veteran[:address][:city], question_num: 16 },
            'postalCode' => { key: INPUT_MAP.veteran[:address][:postalCode], question_num: 18 },
            'state' => { key: INPUT_MAP.veteran[:address][:state], question_num: 17 }
          },
          'veteranHomeAddress' => {
            'street' => { key: INPUT_MAP.veteran[:home_address][:street], question_num: 23 },
            'city' => { key: INPUT_MAP.veteran[:home_address][:city], question_num: 24 },
            'postalCode' => { key: INPUT_MAP.veteran[:home_address][:postalCode], question_num: 26 },
            'state' => { key: INPUT_MAP.veteran[:home_address][:state], question_num: 25 }
          },
          'lastServiceBranch' => { key: INPUT_MAP.veteran[:service][:last_branch_of_service] },
          'dischargeType' => { key: INPUT_MAP.veteran[:service][:discharge_type] },
          'medicareClaimNumber' => { key: INPUT_MAP.medicare_number },
          'spouseGrossIncome' => { key: INPUT_MAP.spouse[:gross_income] },
          'spouseNetIncome' => { key: INPUT_MAP.spouse[:net_income] },
          'spouseOtherIncome' => { key: INPUT_MAP.spouse[:other_income] },
          'veteranGrossIncome' => { key: INPUT_MAP.veteran[:gross_income] },
          'veteranNetIncome' => { key: INPUT_MAP.veteran[:net_income] },
          'veteranOtherIncome' => { key: INPUT_MAP.veteran[:other_income] },
          'deductibleMedicalExpenses' => { key: INPUT_MAP.deductible_medical_expenses },
          'deductibleFuneralExpenses' => { key: INPUT_MAP.deductible_funeral_expenses },
          'deductibleEducationExpenses' => { key: INPUT_MAP.deductible_education_expenses }
        }.freeze
      end
    end
  end
end
