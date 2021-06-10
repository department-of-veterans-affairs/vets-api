# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module HigherLevelReview::V1
      class FormFields
        def first_name
          'F[0].#subform[2].VeteransFirstName[0]'
        end

        def middle_initial
          'F[0].#subform[2].VeteransMiddleInitial1[0]'
        end

        def last_name
          'F[0].#subform[2].VeteransLastName[0]'
        end

        def first_three_ssn
          'F[0].#subform[2].SocialSecurityNumber_FirstThreeNumbers[0]'
        end

        def second_two_ssn
          'F[0].#subform[2].SocialSecurityNumber_SecondTwoNumbers[0]'
        end

        def last_four_ssn
          'F[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]'
        end

        def birth_month
          'F[0].#subform[2].DOBmonth[0]'
        end

        def birth_day
          'F[0].#subform[2].DOBday[0]'
        end

        def birth_year
          'F[0].#subform[2].DOByear[0]'
        end

        def file_number
          'F[0].#subform[2].VAFileNumber[0]'
        end

        def service_number
          'F[0].#subform[2].VeteransServiceNumber[0]'
        end

        def insurance_policy_number
          'F[0].#subform[2].InsurancePolicyNumber[0]'
        end

        def claimant_type(index)
          "F[0].#subform[2].ClaimantType[#{index}]"
        end

        def mailing_address_street
          'F[0].#subform[2].CurrentMailingAddress_NumberAndStreet[0]'
        end

        def mailing_address_unit_number
          'F[0].#subform[2].CurrentMailingAddress_ApartmentOrUnitNumber[0]'
        end

        def mailing_address_city
          'F[0].#subform[2].CurrentMailingAddress_City[0]'
        end

        def mailing_address_state
          'F[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]'
        end

        def mailing_address_country
          'F[0].#subform[2].CurrentMailingAddress_Country[0]'
        end

        def mailing_address_zip_first_5
          'F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
        end

        def mailing_address_zip_last_4
          'F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
        end

        def veteran_phone_number
          'F[0].#subform[2].TELEPHONE[0]'
        end

        def veteran_email
          'F[0].#subform[2].EMAIL[0]'
        end

        def benefit_type(index)
          "F[0].#subform[2].BenefitType[#{index}]"
        end

        def same_office
          'F[0].#subform[2].HIGHERLEVELREVIEWCHECKBOX[0]'
        end

        def informal_conference
          'F[0].#subform[2].INFORMALCONFERENCECHECKBOX[0]'
        end

        def conference_8_to_10
          'F[0].#subform[2].TIME8TO10AM[0]'
        end

        def conference_10_to_1230
          'F[0].#subform[2].TIME10TO1230PM[0]'
        end

        def conference_1230_to_2
          'F[0].#subform[2].TIME1230TO2PM[0]'
        end

        def conference_2_to_430
          'F[0].#subform[2].TIME2TO430PM[0]'
        end

        def rep_name_and_phone_number
          'F[0].#subform[2].REPRESENTATIVENAMEANDTELEPHONENUMBER[0]'
        end

        def signature
          'F[0].#subform[3].SIGNATUREOFVETERANORCLAIMANT[0]'
        end

        def date_signed
          'F[0].#subform[3].DateSigned[0]'
        end

        def contestable_issue_fields_array
          [
            'F[0].#subform[3].SPECIFICISSUE1[1]',
            'F[0].#subform[3].SPECIFICISSUE1[0]',
            'F[0].#subform[3].SPECIFICISSUE3[0]',
            'F[0].#subform[3].SPECIFICISSUE4[0]',
            'F[0].#subform[3].SPECIFICISSUE5[0]',
            'F[0].#subform[3].SPECIFICISSUE6[0]'
          ]
        end

        def issue_decision_date_fields_array
          [
            'F[0].#subform[3].DateofDecision[5]',
            'F[0].#subform[3].DateofDecision[0]',
            'F[0].#subform[3].DateofDecision[1]',
            'F[0].#subform[3].DateofDecision[2]',
            'F[0].#subform[3].DateofDecision[3]',
            'F[0].#subform[3].DateofDecision[4]'
          ]
        end
      end
    end
  end
end
