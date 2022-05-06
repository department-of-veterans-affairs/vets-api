# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module SupplementalClaim
      module V2
        class FormFields
          def veteran_middle_initial
            'form1[0].#subform[2].VeteransMiddleInitial1[0]'
          end

          def claimant_middle_initial
            'form1[0].#subform[2].ClaimantsMiddleInitial1[0]'
          end

          def ssn_first_three
            'form1[0].#subform[2].SocialSecurityNumber_FirstThreeNumbers[0]'
          end

          def ssn_second_two
            'form1[0].#subform[2].SocialSecurityNumber_SecondTwoNumbers[0]'
          end

          def ssn_last_four
            'form1[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]'
          end

          def claimant_ssn_first_three
            'form1[0].#subform[2].ClaimantsSocialSecurityNumber_FirstThreeNumbers[1]'
          end

          def claimant_ssn_second_two
            'form1[0].#subform[2].ClaimantsSocialSecurityNumber_SecondTwoNumbers[1]'
          end

          def claimant_ssn_last_four
            'form1[0].#subform[2].ClaimantsSocialSecurityNumber_LastFourNumbers[1]'
          end

          def file_number
            'form1[0].#subform[2].VAFileNumber[0]'
          end

          def birth_month
            'form1[0].#subform[2].DOBmonth[0]'
          end

          def birth_day
            'form1[0].#subform[2].DOBday[0]'
          end

          def birth_year
            'form1[0].#subform[2].DOByear[0]'
          end

          def claimant_dob
            'F[0].Page_1[0].DateSigned[1]'
          end

          def veteran_service_number
            'form1[0].#subform[2].VeteransServiceNumber[0]'
          end

          def insurance_policy_number
            'form1[0].#subform[2].InsurancePolicyNumber[0]'
          end

          def mailing_address_state
            'form1[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]'
          end

          def mailing_address_country
            'form1[0].#subform[2].CurrentMailingAddress_Country[0]'
          end

          def zip_code_5
            'form1[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
          end

          def veteran_homeless
            'form1[0].#subform[2].ClaimantType[0]'
          end

          # TODO: unsused at the moment
          def zip_code_4
            'form1[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
          end

          def phone
            'form1[0].#subform[2].TELEPHONE[0]'
          end

          def veteran_phone_area_code
            'form1[0].#subform[2].Daytime_Phone_Number_Area_Code[0]'
          end

          def veteran_phone_prefix
            'form1[0].#subform[2].Daytime_Phone_Middle_Three_Numbers[0]'
          end

          def veteran_phone_line_number
            'form1[0].#subform[2].Daytime_Phone_Last_Four_Numbers[0]'
          end

          def veteran_phone_international_number
            'form1[0].#subform[2].International_Telephone_Number_If_Applicable[0]'
          end

          def claimant_type
            'form1[0].#subform[2].RadioButtonList[1]'
          end

          def benefit_type
            'form1[0].#subform[2].RadioButtonList[0]'
          end

          def soc_ssoc_opt_in
            'form1[0].#subform[2].RadioButtonList[2]'
          end

          # currently defaults to YES
          def form_5103_notice_acknowledged
            'form1[0].#subform[3].TIME1230TO2PM[0]'
          end

          def date_signed
            'form1[0].#subform[3].DATESIGNED[0]'
          end

          def contestable_issues_coordinates
            [].tap do |n|
              Structure::MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM.times do |i|
                n << { at: [0, 203 - (30 * i)], width: 402, height: 22, valign: :top }
              end
            end
          end

          def decision_dates_coordinates
            [].tap do |n|
              Structure::MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM.times do |i|
                n << { at: [414, 204 - (30 * i)], width: 120, height: 22, valign: :top }
              end
            end
          end

          def soc_dates_coordinates
            [].tap do |n|
              Structure::MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM.times do |i|
                n << { at: [414, 198 - (30 * i)], width: 120, height: 15 }
              end
            end
          end

          def new_evidence_locations_coordinates
            [].tap do |n|
              Structure::MAX_NUMBER_OF_EVIDENCE_LOCATIONS_FORM.times do |i|
                n << { at: [0, 587 - (44 * i)], width: 404, height: 36, valign: :top }
              end
            end
          end

          def new_evidence_dates_coordinates
            [].tap do |n|
              Structure::MAX_NUMBER_OF_EVIDENCE_LOCATIONS_FORM.times do |i|
                n << { at: [418, 587 - (44 * i)], width: 116, height: 36, valign: :top }
              end
            end
          end

          # rubocop:disable Metrics/MethodLength
          def boxes
            {
              # PAGE 3 '#subform[2]'
              veteran_first_name: { at: [3, 592], width: 195 },
              veteran_last_name: { at: [238, 591], width: 300 },
              preferred_number_and_street: { at: [25, 425], width: 512 },
              preferred_city: { at: [193, 403], width: 307 },
              preferred_state: { at: [60, 378], width: 25 },
              zip_code_5: { at: [290, 380], width: 82 },
              zip_code_4: { at: [290, 380], width: 82 },
              mailing_address_country: { at: [150, 378], width: 25 },
              preferred_email: { at: [275, 348], width: 260 },
              preferred_phone: { at: [3, 348], width: 260 },

              claimant_first_name: { at: [3, 485], width: 192 },
              claimant_last_name: { at: [238, 485], width: 295 },

              contestable_issues: contestable_issues_coordinates,
              decision_dates: decision_dates_coordinates,
              soc_dates: soc_dates_coordinates,

              # PAGE 4 '#subform[3]
              new_evidence_locations: new_evidence_locations_coordinates,
              new_evidence_dates: new_evidence_dates_coordinates,

              signature_of_veteran_claimant_or_rep: { at: [0, 251], width: 410, height: 10, valign: :top },
              print_name_veteran_claimaint_or_rep: { at: [0, 227], width: 540, height: 20, valign: :top  }
            }
          end
          # rubocop:enable Metrics/MethodLength
        end
      end
    end
  end
end
