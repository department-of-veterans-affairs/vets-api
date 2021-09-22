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

          # not sure if this is necessary, but it lists 'veteran'
          def claimant_type(index)
            "form1[0].#subform[2].RadioButtonList[#{index}]"
          end

          def address_state
            'form1[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]'
          end

          def address_country
            'form1[0].#subform[2].CurrentMailingAddress_Country[0]'
          end

          def zip_code_first_five
            'form1[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
          end

          def zip_code_last_four
            'form1[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
          end

          def phone
            'form1[0].#subform[2].TELEPHONE[0]'
          end

          def benefit_type(index)
            "form1[0].#subform[2].RadioButtonList[#{index}]"
          end

          def soc_ssoc_opt_in
            'form1[0].#subform[2].RadioButtonList[2]'
          end

          def decision_date
            'form1[0].#subform[2].DATEOFVADECISION1[0]'
          end

          def date_of_record
            'form1[0].#subform[3].DATEOFTREATMENTRECORDS1[0]'
          end

          def notice_of_acknowledgement_no
            'form1[0].#subform[3].TIME2TO430PM[0]'
          end

          def notice_of_acknowledgement_yes
            'form1[0].#subform[3].TIME1230TO2PM[0]'
          end

          def date_signed
            'form1[0].#subform[3].DATESIGNED[0]'
          end

          def date_signed_alternate_signer
            'form1[0].#subform[3].DATESIGNED[1]'
          end

          def boxes
            # number_of_issue_boxes = 7
            # number_of_new_evidence_submission_boxes = 3
            {
              # PAGE 3 '#subform[2]'
              veteran_first_name: { at: [3, 589], width: 195 },
              veteran_last_name: { at: [238, 589], width: 300 },
              address_number_street: { at: [23, 420], width: 510 },
              address_apartment_or_unit_number: { at: [60, 399], width: 78 },
              address_city: { at: [194, 399], width: 305 },
              email: { at: [286, 343], width: 244 },
              contestable_issue: { at: [0, 207], width: 402, height: 22 }, # first text box only
              soc_date: { at: [435, 208], width: 80 }, # first text box only

              # PAGE 4 '#subform[3]'
              new_evidence_name_location: { at: [0, 207], width: 404, height: 36 }, # first text box only
              signature_of_veteran_claimant_or_rep: { at: [0, 260], width: 408 },
              print_name_veteran_claimaint_or_rep: { at: [0, 235], width: 540 },
              signature_alternate_signer: { at: [0, 98], width: 408 },
              print_name_alternate_signer: { at: [0, 73], width: 540 }
            }
          end
        end
      end
    end
  end
end
