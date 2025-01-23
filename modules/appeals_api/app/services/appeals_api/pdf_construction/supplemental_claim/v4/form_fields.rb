# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module SupplementalClaim
      module V4
        class FormFields
          FIELD_NAMES = {
            veteran_middle_initial: 'form1[0].#subform[3].VeteransMiddleInitial1[0]',
            veteran_ssn_first_three: 'form1[0].#subform[3].Veterans_SocialSecurityNumber_FirstThreeNumbers[0]',
            veteran_ssn_middle_two: 'form1[0].#subform[3].Veterans_SocialSecurityNumber_SecondTwoNumbers[0]',
            veteran_ssn_last_four: 'form1[0].#subform[3].Veterans_SocialSecurityNumber_LastFourNumbers[0]',
            veteran_file_number: 'form1[0].#subform[3].VAFileNumber[0]',
            veteran_dob_month: 'form1[0].#subform[3].DOBmonth[0]',
            veteran_dob_day: 'form1[0].#subform[3].DOBday[0]',
            veteran_dob_year: 'form1[0].#subform[3].DOByear[0]',
            veteran_service_number: 'form1[0].#subform[3].VeteransServiceNumber[0]',
            veteran_insurance_policy_number: 'form1[0].#subform[3].V_A_InsurancePolicyNumber[0]',
            veteran_state_code: 'form1[0].#subform[3].MailingAddress_StateOrProvince[0]',
            veteran_country_code: 'form1[0].#subform[3].MailingAddress_Country[0]',
            veteran_phone_area_code: 'form1[0].#subform[3].Telephone_Number_AreaCode[0]',
            veteran_phone_prefix: 'form1[0].#subform[3].FirstThreeNumbers[0]',
            veteran_phone_line_number: 'form1[0].#subform[3].LastFourNumbers[0]',

            claimant_middle_initial: 'form1[0].#subform[3].ClaimantsMiddleInitial1[0]',
            claimant_type_code: 'form1[0].#subform[3].RadioButtonList[1]',
            claimant_phone_area_code: 'form1[0].#subform[3].Telephone_Number_Area_Code[0]',
            claimant_phone_prefix: 'form1[0].#subform[3].FirstThreeNumbers[1]',
            claimant_phone_line_number: 'form1[0].#subform[3].LastFourNumbers[1]',
            claimant_international_phone: 'form1[0].#subform[3].International_Telephone_Number_If_Applicable[1]',

            signing_appellant_state_code: 'form1[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]',
            signing_appellant_country_code: 'form1[0].#subform[2].CurrentMailingAddress_Country[0]',

            phone_area_code: 'form1[0].#subform[2].Daytime1[0]',
            phone_prefix: 'form1[0].#subform[2].Daytime2[0]',
            phone_line_number: 'form1[0].#subform[2].Daytime3[0]',

            benefit_type_code: 'form1[0].#subform[3].RadioButtonList[0]',
            form_5103_notice_acknowledged: 'form1[0].#subform[5].RadioButtonList[2]',
            veteran_claimant_rep_date_signed: 'form1[0].#subform[3].DATESIGNED[0]',

            alternate_signer_month_signed: 'form1[0].#subform[6].Date_Signed_Month[1]',
            alternate_signer_day_signed: 'form1[0].#subform[6].Date_Signed_Day[1]',
            alternate_signer_year_signed: 'form1[0].#subform[6].Date_Signed_Year[1]',

            veteran_claimant_rep_date_signed_month: 'form1[0].#subform[6].Date_Signed_Month[0]',
            veteran_claimant_rep_date_signed_day: 'form1[0].#subform[6].Date_Signed_Day[0]',
            veteran_claimant_rep_date_signed_year: 'form1[0].#subform[6].Date_Signed_Year[0]',

            ci_decision_date_0_month: 'form1[0].#subform[4].Date_Of_VA_Decision_Notice_Month[0]',
            ci_decision_date_1_month: 'form1[0].#subform[4].Date_Of_VA_Decision_Notice_Month[1]',
            ci_decision_date_2_month: 'form1[0].#subform[4].Date_Of_VA_Decision_Notice_Month[2]',
            ci_decision_date_3_month: 'form1[0].#subform[4].Date_Of_VA_Decision_Notice_Month[3]',
            ci_decision_date_4_month: 'form1[0].#subform[4].Date_Of_VA_Decision_Notice_Month[4]',
            ci_decision_date_5_month: 'form1[0].#subform[4].Date_Of_VA_Decision_Notice_Month[5]',
            ci_decision_date_6_month: 'form1[0].#subform[4].Date_Of_VA_Decision_Notice_Month[6]',
            ci_decision_date_7_month: 'form1[0].#subform[4].Date_Of_VA_Decision_Notice_Month[7]',
            ci_decision_date_8_month: 'form1[0].#subform[4].Date_Of_VA_Decision_Notice_Month[8]',

            ci_decision_date_0_day: 'form1[0].#subform[4].Date_Day[0]',
            ci_decision_date_1_day: 'form1[0].#subform[4].Date_Day[1]',
            ci_decision_date_2_day: 'form1[0].#subform[4].Date_Day[2]',
            ci_decision_date_3_day: 'form1[0].#subform[4].Date_Day[3]',
            ci_decision_date_4_day: 'form1[0].#subform[4].Date_Day[4]',
            ci_decision_date_5_day: 'form1[0].#subform[4].Date_Day[5]',
            ci_decision_date_6_day: 'form1[0].#subform[4].Date_Day[6]',
            ci_decision_date_7_day: 'form1[0].#subform[4].Date_Day[7]',
            ci_decision_date_8_day: 'form1[0].#subform[4].Date_Day[8]',

            ci_decision_date_0_year: 'form1[0].#subform[4].Date_Year[0]',
            ci_decision_date_1_year: 'form1[0].#subform[4].Date_Year[1]',
            ci_decision_date_2_year: 'form1[0].#subform[4].Date_Year[2]',
            ci_decision_date_3_year: 'form1[0].#subform[4].Date_Year[3]',
            ci_decision_date_4_year: 'form1[0].#subform[4].Date_Year[4]',
            ci_decision_date_5_year: 'form1[0].#subform[4].Date_Year[5]',
            ci_decision_date_6_year: 'form1[0].#subform[4].Date_Year[6]',
            ci_decision_date_7_year: 'form1[0].#subform[4].Date_Year[7]',
            ci_decision_date_8_year: 'form1[0].#subform[4].Date_Year[8]'
          }.freeze

          def initialize
            FIELD_NAMES.each { |field, name| define_singleton_method(field) { name } }
          end

          # rubocop:disable Metrics/MethodLength
          def boxes
            row_height_pg1 = 30.6
            row_height_pg2 = 34.6
            {
              veteran_first_name: { at: [-0.2, 452.3], width: 205.0, height: 13.65 },
              veteran_last_name: { at: [236.1, 452.3], width: 308.5, height: 13.65 },
              veteran_email: { at: [268, 293.5], width: 280, height: 34.3, valign: :top },
              veteran_number_and_street: { at: [31.2, 358.45], width: 513.4, height: 13.65 },
              veteran_city: { at: [194.9, 339.7], width: 315, height: 13.65 },
              veteran_zip_code: { at: [273.7, 321.0], width: 84.6, height: 13.65 },
              veteran_international_phone: { at: [153, 275], width: 110, height: 15 },

              claimant_first_name: { at: [0.9, 215.4], width: 204.3, height: 13.6 },
              claimant_last_name: { at: [237, 215.4], width: 308.3, height: 13.6 },
              claimant_type_other_text: { at: [271, 129], width: 105 },
              claimant_number_and_street: { at: [32.65, 99.8], width: 512.6, height: 13.65 },
              claimant_city: { at: [196.1, 81.15], width: 313.9, height: 13.65 },
              claimant_zip_code: { at: [274.8, 62.35], width: 84.6, height: 13.65 },
              claimant_email: { at: [267, 33.8], width: 283, height: 33.1, valign: :top },

              international_phone: { at: [151, 15], width: 114, height: 15 },

              contestable_issues: Structure::MAX_ISSUES_ON_MAIN_FORM.times.map do |i|
                { at: [-5, 274 - (row_height_pg1 * i)], width: 412, height: 28, valign: :top }
              end,

              soc_dates: Structure::MAX_ISSUES_ON_MAIN_FORM.times.map do |i|
                { at: [414, 262 - (row_height_pg1 * i) - (i * 0.42)], width: 120, height: 14 }
              end,
              new_evidence_locations: Structure::MAX_EVIDENCE_LOCATIONS_ON_MAIN_FORM.times.map do |i|
                { at: [-5, 462.3 - (row_height_pg2 * i) - (1.4 * i)], width: 244, height: 32.6, valign: :top }
              end,
              new_evidence_dates: Structure::MAX_EVIDENCE_LOCATIONS_ON_MAIN_FORM.times.map do |i|
                {
                  at: [241, 463.5 - (row_height_pg2 * i) - (1.4 * i)],
                  width: 145.8,
                  height: 34.5,
                  valign: :center
                }
              end,
              veteran_claimant_rep_signature: { at: [-5, 677], width: 333, valign: :top },
              alternate_signer_signature: { at: [-3, 261], width: 304, height: 25, valign: :top }
            }.freeze
          end
          # rubocop:enable Metrics/MethodLength
        end
      end
    end
  end
end
