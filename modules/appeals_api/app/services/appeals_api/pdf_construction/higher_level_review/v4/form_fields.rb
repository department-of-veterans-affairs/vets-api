# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module HigherLevelReview
      module V4
        class FormFields
          # rubocop:disable Naming/VariableNumber
          # rubocop:disable Layout/LineLength
          FIELD_NAMES = {
            veteran_middle_initial: 'form1[0].#subform[2].Veterans_Middle_Initial1[0]',
            veteran_ssn_first_three: 'form1[0].#subform[2].Veterans_SocialSecurityNumber_FirstThreeNumbers[0]',
            veteran_ssn_middle_two: 'form1[0].#subform[2].Veterans_SocialSecurityNumber_SecondTwoNumbers[0]',
            veteran_ssn_last_four: 'form1[0].#subform[2].Veterans_SocialSecurityNumber_LastFourNumbers[0]',
            veteran_dob_day: 'form1[0].#subform[2].DOBday[0]',
            veteran_dob_month: 'form1[0].#subform[2].DOBmonth[0]',
            veteran_dob_year: 'form1[0].#subform[2].DOByear[0]',
            veteran_insurance_policy_number: 'form1[0].#subform[2].VA_Insurance_Policy_Number_If_Applicable[0]',
            veteran_state_code: 'form1[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]',
            veteran_country_code: 'form1[0].#subform[2].CurrentMailingAddress_Country[0]',
            veteran_homeless: 'form1[0].#subform[2].I_Am_Experiencing_Or_At_Risk_Of_Homelessness[0]',
            veteran_phone_area_code: 'form1[0].#subform[2].Telephone_Number_Area_Code[0]',
            veteran_phone_prefix: 'form1[0].#subform[2].Telephone_Middle_Three_Numbers[0]',
            veteran_phone_line_number: 'form1[0].#subform[2].Telephone_Last_Four_Numbers[0]',
            claimant_middle_initial: 'form1[0].#subform[2].Claimants_Middle_Initial1[0]',
            claimant_ssn_first_three: 'form1[0].#subform[2].Claimants_SocialSecurityNumber_FirstThreeNumbers[0]',
            claimant_ssn_middle_two: 'form1[0].#subform[2].Claimants_SocialSecurityNumber_SecondTwoNumbers[0]',
            claimant_ssn_last_four: 'form1[0].#subform[2].Claimants_SocialSecurityNumber_LastFourNumbers[0]',
            claimant_dob_day: 'form1[0].#subform[2].DOBday[1]',
            claimant_dob_month: 'form1[0].#subform[2].DOBmonth[1]',
            claimant_dob_year: 'form1[0].#subform[2].DOByear[1]',
            claimant_state_code: 'form1[0].#subform[2].CurrentMailingAddress_StateOrProvince[1]',
            claimant_country_code: 'form1[0].#subform[2].CurrentMailingAddress_Country[1]',
            claimant_phone_area_code: 'form1[0].#subform[2].Telephone_Number_Area_Code[1]',
            claimant_phone_prefix: 'form1[0].#subform[2].Daytime_Phone_Middle_Three_Numbers[1]',
            claimant_phone_line_number: 'form1[0].#subform[2].Daytime_Phone_Last_Four_Numbers[1]',
            informal_conference: 'form1[0].#subform[3].Checkbox_I_Would_Like_An_Optional_Informal_Conference[0]',
            conference_8_to_12: 'form1[0].#subform[3].Checkbox_Contact_Veteran_By_Phone_In_The_Morning_Based_On_Time_Zone[0]',
            conference_rep_8_to_12: 'form1[0].#subform[3].Checkbox_Contact_The_Representative_By_Phone_In_The_Morning_Hours_Based_On_Time_Zone[0]',
            conference_12_to_1630: 'form1[0].#subform[3].Checkbox_Contact_The_Veteran_Claimant_By_Phone_In_The_Afternoon_Based_On_Time_Zone[0]',
            conference_rep_12_to_1630: 'form1[0].#subform[3].Checkbox_Contact_The_Representative_By_Phone_In_The_Afternoon_Hours_Based_On_Time_Zone[0]',
            rep_phone_area_code: 'form1[0].#subform[3].Representatives_Telephone_Number_Area_Code[0]',
            rep_phone_prefix: 'form1[0].#subform[3].Telephone_Middle_Three_Numbers[2]',
            rep_phone_line_number: 'form1[0].#subform[3].Telephone_Last_Four_Numbers[2]',
            veteran_claimant_date_signed_month: 'form1[0].#subform[4].Date_Signed_Month[0]',
            veteran_claimant_date_signed_day: 'form1[0].#subform[4].Date_Signed_Day[0]',
            veteran_claimant_date_signed_year: 'form1[0].#subform[4].Date_Signed_Year[0]'
            # NOTE: rep signature not yet supported
          }.freeze
          # rubocop:enable Naming/VariableNumber
          # rubocop:enable Layout/LineLength

          def initialize
            FIELD_NAMES.each { |field, name| define_singleton_method(field) { name } }
          end

          def benefit_type_field
            'form1[0].#subform[2].RadioButtonList[0]'
          end

          def contestable_issue_day_field(subform, index)
            "form1[0].#subform[#{subform}].Date_Day[#{index}]"
          end

          def contestable_issue_month_field(subform, index)
            "form1[0].#subform[#{subform}].Date_Month[#{index}]"
          end

          def contestable_issue_year_field(subform, index)
            "form1[0].#subform[#{subform}].Date_Year[#{index}]"
          end

          # rubocop:disable Metrics/MethodLength
          def boxes
            {
              veteran_first_name: { at: [3, 560], width: 190, height: 15 },
              veteran_last_name: { at: [225, 560.3], width: 290, height: 15 },
              veteran_file_number: { at: [197, 525.7], width: 152, height: 15 },
              veteran_number_and_street: { at: [27, 460.4], width: 511, height: 14.1 },
              veteran_city: { at: [199, 439.4], width: 305.5, height: 14.6 },
              veteran_zip_code: { at: [297, 416], width: 79, height: 15.3 },
              veteran_email: { at: [7, 335], width: 500, height: 15 },
              veteran_phone_extension: { at: [224, 378], width: 50, height: 10 },
              veteran_international_phone: { at: [376, 366.6], width: 113, height: 12.7 },
              claimant_first_name: { at: [2, 288.8], width: 190, height: 15 },
              claimant_last_name: { at: [228, 288.8], width: 289.5, height: 15 },
              claimant_number_and_street: { at: [26.1, 224], width: 510, height: 14.6 },
              claimant_city: { at: [199.6, 204.1], width: 308, height: 14.7 },
              claimant_zip_code: { at: [297, 181.7], width: 80, height: 15.1 },
              claimant_email: { at: [2.2, 117.5], width: 511, height: 14.4 },
              claimant_international_phone: { at: [368.0, 146.3], width: 113, height: 12 },
              rep_first_name: { at: [2.2, 542.2], width: 192, height: 14.3 },
              rep_last_name: { at: [209, 542.8], width: 291, height: 14.5 },
              rep_phone_extension: { at: [215, 510], width: 100 },
              rep_international_phone: { at: [245, 510], width: 195, height: 13 },
              rep_email: { at: [2, 476.7], width: 513, height: 13.8 },
              veteran_claimant_signature: { at: [-5, 315], width: 371, height: 18 }
            }.merge(contestable_issues_table_boxes) # NOTE: rep signature field is not yet supported
          end

          private

          def contestable_issues_table_boxes
            # The contestable issues table is split across two pages. Horizontal placement of its parts is different on
            # each page, and row heights are inconsistent within each part of the table.
            table_left_pg1 = -4.7
            table_left_pg2 = -3.5
            left_col_width = 371.4
            right_col_width_pg = 170

            ci_pos = {}
            ci_pos[:issue_pg1] =
              [{ at: [table_left_pg1, 321.1], width: left_col_width, height: 22.0, valign: :top },
               { at: [table_left_pg1, 273.9], width: left_col_width, height: 20.4, valign: :top },
               { at: [table_left_pg1, 229.6], width: left_col_width, height: 21.7, valign: :top },
               { at: [table_left_pg1, 183.1], width: left_col_width, height: 22.1, valign: :top },
               { at: [table_left_pg1, 136.0], width: left_col_width, height: 22.0, valign: :top },
               { at: [table_left_pg1,  89.0], width: left_col_width, height: 22.1, valign: :top },
               { at: [table_left_pg1,  42.2], width: left_col_width, height: 23.2, valign: :top }]

            ci_pos[:disagreement_area_pg1] = Structure::MAX_ISSUES_FIRST_PAGE.times.map do |i|
              {
                at: [table_left_pg1, ci_pos[:issue_pg1][i][:at][1] - ci_pos[:issue_pg1][i][:height]],
                width: left_col_width, height: ci_pos[:issue_pg1][i][:height]
              }
            end

            ci_pos[:soc_date_pg1] = Structure::MAX_ISSUES_FIRST_PAGE.times.map do |i|
              {
                at: [table_left_pg1 + left_col_width + 7, ci_pos[:issue_pg1][i][:at][1] - 2],
                width: right_col_width_pg, height: 15, valign: :top
              }
            end

            ci_pos[:issue_pg2] =
              [{ at: [table_left_pg2, 673.8], width: left_col_width, height: 21.6, valign: :top },
               { at: [table_left_pg2, 625.8], width: left_col_width, height: 22.4, valign: :top },
               { at: [table_left_pg2, 577.7], width: left_col_width, height: 22.5, valign: :top },
               { at: [table_left_pg2, 528.8], width: left_col_width, height: 22.6, valign: :top },
               { at: [table_left_pg2, 480.0], width: left_col_width, height: 22.6, valign: :top },
               { at: [table_left_pg2, 431.8], width: left_col_width, height: 22.6, valign: :top }]

            ci_pos[:disagreement_area_pg2] = Structure::MAX_ISSUES_SECOND_PAGE.times.map do |i|
              { at: [table_left_pg2, ci_pos[:issue_pg2][i][:at][1] - ci_pos[:issue_pg2][i][:height]],
                width: left_col_width, height: ci_pos[:issue_pg2][i][:height] }
            end

            ci_pos[:soc_date_pg2] = Structure::MAX_ISSUES_SECOND_PAGE.times.map do |i|
              { at: [table_left_pg2 + left_col_width + 7, ci_pos[:issue_pg2][i][:at][1] - 2],
                width: right_col_width_pg, height: 15, valign: :top }
            end

            ci_pos
          end
          # rubocop:enable Metrics/MethodLength
        end
      end
    end
  end
end
