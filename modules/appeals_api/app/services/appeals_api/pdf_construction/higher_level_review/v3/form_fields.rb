# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module HigherLevelReview
      module V3
        class FormFields
          # rubocop:disable Naming/VariableNumber
          FIELD_NAMES = {
            veteran_middle_initial: 'form1[0].#subform[2].Veteran_Middle_Initial1[0]',
            veteran_ssn_first_three: 'form1[0].#subform[2].ClaimantsSocialSecurityNumber_FirstThreeNumbers[0]',
            veteran_ssn_middle_two: 'form1[0].#subform[2].ClaimantsSocialSecurityNumber_SecondTwoNumbers[0]',
            veteran_ssn_last_four: 'form1[0].#subform[2].ClaimantsSocialSecurityNumber_LastFourNumbers[0]',
            veteran_dob_day: 'form1[0].#subform[2].DOBmonth[0]',
            veteran_dob_month: 'form1[0].#subform[2].DOBday[0]',
            veteran_dob_year: 'form1[0].#subform[2].DOByear[0]',
            veteran_insurance_policy_number: 'form1[0].#subform[2].ClaimantsLastName[1]',
            veteran_state_code: 'form1[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]',
            veteran_country_code: 'form1[0].#subform[2].CurrentMailingAddress_Country[0]',
            veteran_homeless: 'form1[0].#subform[2].ClaimantType[0]',
            veteran_phone_area_code: 'form1[0].#subform[2].Daytime_Phone_Number_Area_Code[0]',
            veteran_phone_prefix: 'form1[0].#subform[2].Daytime_Phone_Middle_Three_Numbers[0]',
            veteran_phone_line_number: 'form1[0].#subform[2].Daytime_Phone_Last_Four_Numbers[0]',
            claimant_middle_initial: 'form1[0].#subform[2].Veteran_Middle_Initial1[1]',
            claimant_ssn_first_three: 'form1[0].#subform[2].ClaimantsSocialSecurityNumber_FirstThreeNumbers[1]',
            claimant_ssn_middle_two: 'form1[0].#subform[2].ClaimantsSocialSecurityNumber_SecondTwoNumbers[1]',
            claimant_ssn_last_four: 'form1[0].#subform[2].ClaimantsSocialSecurityNumber_LastFourNumbers[1]',
            claimant_dob_day: 'form1[0].#subform[2].DOBday[1]',
            claimant_dob_month: 'form1[0].#subform[2].DOBmonth[1]',
            claimant_dob_year: 'form1[0].#subform[2].DOByear[1]',
            claimant_state_code: 'form1[0].#subform[2].CurrentMailingAddress_StateOrProvince[1]',
            claimant_country_code: 'form1[0].#subform[2].CurrentMailingAddress_Country[1]',
            claimant_zip_code: 'form1[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[1]',
            claimant_phone_area_code: 'form1[0].#subform[2].Daytime_Phone_Number_Area_Code[1]',
            claimant_phone_prefix: 'form1[0].#subform[2].Daytime_Phone_Middle_Three_Numbers[1]',
            claimant_phone_line_number: 'form1[0].#subform[2].Daytime_Phone_Last_Four_Numbers[1]',
            informal_conference: 'form1[0].#subform[3].HIGHERLEVELREVIEWCHECKBOX[0]',
            conference_8_to_12: 'form1[0].#subform[3].TIME8TO10AM[0]',
            conference_12_to_1630: 'form1[0].#subform[3].TIME1230TO2PM[0]',
            conference_rep_8_to_12: 'form1[0].#subform[3].TIME10TO1230PM[0]',
            conference_rep_12_to_1630: 'form1[0].#subform[3].TIME2TO430PM[0]',
            rep_phone_area_code: 'form1[0].#subform[3].Daytime_Phone_Number_Area_Code[2]',
            rep_phone_prefix: 'form1[0].#subform[3].Daytime_Phone_Middle_Three_Numbers[2]',
            rep_phone_line_number: 'form1[0].#subform[3].Daytime_Phone_Last_Four_Numbers[2]',
            veteran_claimant_date_signed_month: 'form1[0].#subform[4].DOBmonth[15]',
            veteran_claimant_date_signed_day: 'form1[0].#subform[4].DOBday[15]',
            veteran_claimant_date_signed_year: 'form1[0].#subform[4].DOByear[15]'
            # NOTE: rep signature not yet supported
          }.freeze
          # rubocop:enable Naming/VariableNumber

          def initialize
            FIELD_NAMES.each { |field, name| define_singleton_method(field) { name } }
          end

          def benefit_type_field(benefit_type)
            index = FormData::BENEFIT_TYPE_CODES.find_index { |k, _| k == benefit_type }

            "form1[0].#subform[2].BenefitType[#{index}]"
          end

          def contestable_issue_day_field(subform, index)
            "form1[0].#subform[#{subform}].DOBday[#{index}]"
          end

          def contestable_issue_month_field(subform, index)
            "form1[0].#subform[#{subform}].DOBmonth[#{index}]"
          end

          def contestable_issue_year_field(subform, index)
            "form1[0].#subform[#{subform}].DOByear[#{index}]"
          end
        end
      end
    end
  end
end
