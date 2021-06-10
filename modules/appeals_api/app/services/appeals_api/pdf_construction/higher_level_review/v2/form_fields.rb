# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module HigherLevelReview::V2
      class FormFields
        FIRST_PAGE_ISSUES_ROW_COUNT = 7
        SECOND_PAGE_ISSUES_ROW_COUNT = 6

        def middle_initial
          'form1[0].#subform[2].Veteran_Middle_Initial1[0]'
        end

        def first_three_ssn
          'form1[0].#subform[2].ClaimantsSocialSecurityNumber_FirstThreeNumbers[0]'
        end

        def second_two_ssn
          'form1[0].#subform[2].ClaimantsSocialSecurityNumber_SecondTwoNumbers[0]'
        end

        def last_four_ssn
          'form1[0].#subform[2].ClaimantsSocialSecurityNumber_LastFourNumbers[0]'
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

        def file_number
          'form1[0].#subform[2].VAFileNumber[0]'
        end

        def service_number
          'F[0].#subform[2].VeteransServiceNumber[0]'
        end

        def insurance_policy_number
          'form1[0].#subform[2].ClaimantsLastName[1]'
        end

        def mailing_address_street
          'form1[0].#subform[2].CurrentMailingAddress_NumberAndStreet[0]'
        end

        def mailing_address_unit_number
          'form1[0].#subform[2].CurrentMailingAddress_ApartmentOrUnitNumber[0]'
        end

        def mailing_address_city
          'form1[0].#subform[2].CurrentMailingAddress_City[0]'
        end

        def mailing_address_state
          'form1[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]'
        end

        def mailing_address_country
          'form1[0].#subform[2].CurrentMailingAddress_Country[0]'
        end

        def mailing_address_zip_first_5
          'form1[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
        end

        def mailing_address_zip_last_4
          'form1[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
        end

        def veteran_homeless
          'form1[0].#subform[2].ClaimantType[0]'
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

        def veteran_email
          'form1[0].#subform[2].CurrentMailingAddress_NumberAndStreet[2]'
        end

        def benefit_type(index)
          "form1[0].#subform[2].BenefitType[#{index}]"
        end

        def informal_conference
          'form1[0].#subform[3].HIGHERLEVELREVIEWCHECKBOX[0]'
        end

        def conference_8_to_12
          'form1[0].#subform[3].TIME8TO10AM[0]'
        end

        def conference_12_to_1630
          'form1[0].#subform[3].TIME1230TO2PM[0]'
        end

        def conference_rep_8_to_12
          'form1[0].#subform[3].TIME10TO1230PM[0]'
        end

        def conference_rep_12_to_1630
          'form1[0].#subform[3].TIME2TO430PM[0]'
        end

        def rep_phone_area_code
          'form1[0].#subform[3].Daytime_Phone_Number_Area_Code[2]'
        end

        def rep_phone_prefix
          'form1[0].#subform[3].Daytime_Phone_Middle_Three_Numbers[2]'
        end

        def rep_phone_line_number
          'form1[0].#subform[3].Daytime_Phone_Last_Four_Numbers[2]'
        end

        def rep_email
          'form1[0].#subform[3].CurrentMailingAddress_NumberAndStreet[4]'
        end

        def sso_ssoc_opt_in
          'form1[0].#subform[3].RadioButtonList[0]'
        end

        def signature
          'form1[0].#subform[4].SIGNATUREOFVETERANORCLAIMANT[0]'
        end

        def date_signed_month
          'form1[0].#subform[4].DOBmonth[15]'
        end

        def date_signed_day
          'form1[0].#subform[4].DOBday[15]'
        end

        def date_signed_year
          'form1[0].#subform[4].DOByear[15]'
        end

        def issue_decision_date_fields(index)
          subform = index <= 6 ? 3 : 4
          offset = index + 2

          { month: "form1[0].#subform[#{subform}].DOBmonth[#{offset}]",
            day: "form1[0].#subform[#{subform}].DOBday[#{offset}]",
            year: "form1[0].#subform[#{subform}].DOByear[#{offset}]" }
        end

        # rubocop:disable Metrics/MethodLength
        def boxes
          { first_name: { at: [3, 560], width: 195 },
            last_name: { at: [230, 560], width: 293 },
            number_and_street: { at: [29, 462], width: 512 },
            city: { at: [200, 441], width: 307 },
            veteran_email: { at: [8, 335], width: 513 },
            veteran_phone_extension: { at: [220, 378], width: 50, height: 10 },
            rep_first_name: { at: [11, 586], width: 195 },
            rep_last_name: { at: [225, 586], width: 293 },
            rep_email: { at: [11, 525], width: 513 },
            rep_international_number: { at: [275, 555], width: 195 },
            rep_domestic_ext: { at: [225, 555], width: 50 },
            issues_pg1: [].tap do |n|
              FIRST_PAGE_ISSUES_ROW_COUNT.times { |i| n << { at: [-3, 320 - (46.5 * i)], width: 369, height: 43 } }
            end,
            issues_pg2: [].tap do |n|
              SECOND_PAGE_ISSUES_ROW_COUNT.times { |i| n << { at: [-3, 675 - (46.5 * i)], width: 369, height: 43 } }
            end,
            soc_date_pg1: [].tap do |n|
              FIRST_PAGE_ISSUES_ROW_COUNT.times { |i| n << { at: [375, 315 - (46.5 * i)], width: 160, height: 15 } }
            end,
            soc_date_pg2: [].tap do |n|
              SECOND_PAGE_ISSUES_ROW_COUNT.times { |i| n << { at: [380, 670 - (46.5 * i)], width: 160, height: 15 } }
            end,
            signature: { at: [-3, 329], width: 369, height: 18 },
            # The rest aren't currently used, but kept for if/when we need them
            rep_signature_first_name: { at: [12, 229], width: 195 },
            rep_signature_last_name: { at: [226, 229], width: 293 },
            rep_signature: { at: [-4, 201], width: 369, height: 18 } }
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
