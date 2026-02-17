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
            veteran_dob_day: 'form1[0].#subform[2].DOBday[0]',
            veteran_dob_month: 'form1[0].#subform[2].DOBmonth[0]',
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

          # rubocop:disable Metrics/MethodLength
          def boxes
            {
              veteran_first_name: { at: [3, 559.7], width: 195, height: 14.4 },
              veteran_last_name: { at: [229, 559.7], width: 293, height: 14.4 },
              veteran_file_number: { at: [199, 527.2], width: 154, height: 14.4 },
              veteran_number_and_street: { at: [27, 461], width: 512, height: 13.6 },
              veteran_city: { at: [199, 440.5], width: 307, height: 14 },
              veteran_zip_code: { at: [297, 417.8], width: 82, height: 15.3 },
              veteran_email: { at: [7, 334.5], width: 515, height: 13.6 },
              veteran_phone_extension: { at: [225, 378], width: 50, height: 10 },
              veteran_international_phone: { at: [381, 366.3], width: 114, height: 12.8 },
              claimant_first_name: { at: [8, 289.3], width: 193, height: 14.3 },
              claimant_last_name: { at: [235, 289.1], width: 293, height: 14.1 },
              claimant_number_and_street: { at: [28, 218.9], width: 514, height: 13.5 },
              claimant_city: { at: [199.2, 199.4], width: 308, height: 14 },
              claimant_zip_code: { at: [297, 177.1], width: 82, height: 14.4 },
              claimant_email: { at: [8, 113.7], width: 513.5, height: 13.8 },
              claimant_international_phone: { at: [382, 143.8], width: 115, height: 12.8 },
              rep_first_name: { at: [11, 574.6], width: 195, height: 13.6 },
              rep_last_name: { at: [225, 574.6], width: 293, height: 13.6 },
              rep_phone_extension: { at: [225, 546], width: 100 },
              rep_international_phone: { at: [245, 546], width: 195 },
              rep_email: { at: [11, 514.2], width: 513, height: 13 },
              veteran_claimant_signature: { at: [-3, 329], width: 371, height: 18 }
            }.merge(contestable_issues_table_boxes) # NOTE: rep signature field is not yet supported
          end

          private

          def contestable_issues_table_boxes
            # The contestable issues table is split across two pages. Horizontal placement of its parts is different on
            # each page, and row heights are inconsistent within each part of the table.
            table_left_pg1 = -5
            table_left_pg2 = -3
            table_top_pg1 = 352
            table_top_pg2 = 673
            left_col_width = 374
            right_col_width_pg2 = 170
            row_height = 46.8

            {
              issue_pg1: Structure::MAX_ISSUES_FIRST_PAGE.times.map do |i|
                {
                  at: [table_left_pg1, table_top_pg1 - (row_height * i) + (i * 1.4)],
                  width: left_col_width, height: 23, valign: :top
                }
              end,
              issue_pg2: Structure::MAX_ISSUES_SECOND_PAGE.times.map do |i|
                {
                  at: [table_left_pg2, table_top_pg2 - (row_height * i)],
                  width: left_col_width, height: 23, valign: :top
                }
              end,
              soc_date_pg1: Structure::MAX_ISSUES_FIRST_PAGE.times.map do |i|
                {
                  at: [table_left_pg1 + left_col_width + 4, table_top_pg1 - (row_height * i) + (i * 1.4)],
                  width: right_col_width_pg2, height: 15
                }
              end,
              soc_date_pg2: Structure::MAX_ISSUES_SECOND_PAGE.times.map do |i|
                { at: [table_left_pg2 + left_col_width + 4, table_top_pg2 - (row_height * i)], width: 160, height: 15 }
              end,
              disagreement_area_pg1: Structure::MAX_ISSUES_FIRST_PAGE.times.map do |i|
                {
                  at: [table_left_pg1, table_top_pg1 - (row_height * i) - 21 + (i * 1.2)],
                  width: left_col_width, height: 15
                }
              end,
              disagreement_area_pg2: Structure::MAX_ISSUES_SECOND_PAGE.times.map do |i|
                { at: [table_left_pg2, table_top_pg2 - (row_height * i) - 21], width: left_col_width, height: 15 }
              end
            }
          end
          # rubocop:enable Metrics/MethodLength
        end
      end
    end
  end
end
