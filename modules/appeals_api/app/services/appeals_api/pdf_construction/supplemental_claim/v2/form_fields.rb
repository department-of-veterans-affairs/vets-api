# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module SupplementalClaim
      module V2
        class FormFields
          def veteran_middle_initial
            'form1[0].#subform[2].VeteransMiddleInitial1[0]'
          end

          def ssn_first_three
            'form1[0].#subform[2].SocialSecurityNumber_FirstThreeNumbers[0]'
          end

          def ssn_middle_two
            'form1[0].#subform[2].SocialSecurityNumber_SecondTwoNumbers[0]'
          end

          def ssn_last_four
            'form1[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]'
          end

          def file_number
            'form1[0].#subform[2].VAFileNumber[0]'
          end

          def veteran_dob_month
            'form1[0].#subform[2].DOBmonth[0]'
          end

          def veteran_dob_day
            'form1[0].#subform[2].DOBday[0]'
          end

          def veteran_dob_year
            'form1[0].#subform[2].DOByear[0]'
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

          # TODO: unsused at the moment
          def zip_code_4
            'form1[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
          end

          def phone
            'form1[0].#subform[2].TELEPHONE[0]'
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

          def date_signed
            'form1[0].#subform[3].DATESIGNED[0]'
          end

          def boxes
            {
              # PAGE 3 '#subform[2]'
              veteran_first_name: { at: [3, 592], width: 195 },
              veteran_last_name: { at: [238, 591], width: 300 },
              mailing_address_number_and_street: { at: [23, 423], width: 510 },
              mailing_address_apartment_or_unit_number: { at: [60, 401], width: 78 },
              mailing_address_city_and_box: { at: [195, 402], width: 308 },
              email: { at: [286, 347], width: 244 },

              contestable_issues: handle_contestable_issues,
              decision_dates: handle_decision_dates,
              soc_dates: handle_soc_dates,

              # PAGE 4 '#subform[3]
              new_evidence_locations: handle_new_evidence_locations,
              new_evidence_dates: handle_new_evidence_dates,

              signature_of_veteran_claimant_or_rep: { at: [0, 251], width: 415, height: 20, valign: :top },
              print_name_veteran_claimaint_or_rep: { at: [0, 227], width: 540, height: 20, valign: :top  }
            }
          end
        end

        private

        def number_of_issues_on_form
          Structure::MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM
        end

        def number_of_evidence_submission_boxes
          Structure::MAX_NUMBER_OF_EVIDENCE_LOCATIONS_FORM
        end

        def handle_contestable_issues
          [].tap do |n|
            number_of_issues_on_form.times do |i|
              n << { at: [0, 203 - (30 * i)], width: 402, height: 22, valign: :top }
            end
          end
        end

        def handle_decision_dates
          [].tap do |n|
            number_of_issues_on_form.times do |i|
              n << { at: [414, 204 - (30 * i)], width: 120, height: 22, valign: :top }
            end
          end
        end

        def handle_soc_dates
          [].tap do |n|
            number_of_issues_on_form.times do |i|
              n << { at: [414, 198 - (30 * i)], width: 120, height: 15 }
            end
          end
        end

        def handle_new_evidence_locations
          [].tap do |n|
            number_of_evidence_submission_boxes.times do |i|
              n << { at: [0, 587 - (44 * i)], width: 404, height: 36, valign: :top }
            end
          end
        end

        def handle_new_evidence_dates
          [].tap do |n|
            number_of_evidence_submission_boxes.times do |i|
              n << { at: [418, 587 - (44 * i)], width: 116, height: 36, valign: :top }
            end
          end
        end
      end
    end
  end
end
