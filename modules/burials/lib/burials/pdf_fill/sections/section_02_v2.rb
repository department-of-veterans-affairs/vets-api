# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section II: Claimant Information
    class Section2V2 < Section
      # Section configuration hash
      KEY = {
        'claimantFullName' => { # start claimant information
          'first' => {
            key: 'form1[0].#subform[82].ClaimantsFirstName[0]',
            limit: 12,
            question_num: 7,
            question_label: "Claimant's First Name",
            question_text: "CLAIMANT'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'form1[0].#subform[82].ClaimantsMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[82].ClaimantsLastName[0]',
            limit: 18,
            question_num: 7,
            question_label: "Claimant's Last Name",
            question_text: "CLAIMANT'S LAST NAME"
          }
        },
        'claimantSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[82].Claimants_SocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[82].Claimants_SocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[82].Claimants_SocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'claimantDateOfBirth' => {
          'month' => {
            key: 'form1[0].#subform[82].Claimants_DOBmonth[0]',
            limit: 2,
            question_num: 9,
            question_suffix: 'A',
            question_label: "Veteran/Claimant's Identification Information > Claimant's Date Of Birth (Mm-Dd-Yyyy)",
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > CLAIMANT\'S DATE OF BIRTH (MM-DD-YYYY)'
          },
          'day' => {
            key: 'form1[0].#subform[82].Claimants_DOBday[0]',
            limit: 2,
            question_num: 9,
            question_suffix: 'B',
            question_label: "Veteran/Claimant's Identification Information > Claimant's Date Of Birth (Mm-Dd-Yyyy)",
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > CLAIMANT\'S DATE OF BIRTH (MM-DD-YYYY)'
          },
          'year' => {
            key: 'form1[0].#subform[82].Claimants_DOByear[0]',
            limit: 4,
            question_num: 9,
            question_suffix: 'C',
            question_label: "Veteran/Claimant's Identification Information > Claimant's Date Of Birth (Mm-Dd-Yyyy)",
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > CLAIMANT\'S DATE OF BIRTH (MM-DD-YYYY)'
          }
        },
        'claimantAddress' => {
          'street' => {
            key: 'form1[0].#subform[82].CurrentMailingAddress_NumberAndStreet[0]',
            limit: 30,
            question_num: 10,
            question_label: "Claimant's Address - Street",
            question_text: "CLAIMANT'S ADDRESS - STREET"
          },
          'street2' => {
            key: 'form1[0].#subform[82].CurrentMailingAddress_ApartmentOrUnitNumber[0]',
            limit: 5,
            question_num: 10,
            question_label: "Claimant's Address - Apt/Unit No.",
            question_text: "CLAIMANT'S ADDRESS - APT/UNIT NO."
          },
          'city' => {
            key: 'form1[0].#subform[82].CurrentMailingAddress_City[0]',
            limit: 18,
            question_num: 10,
            question_label: "Claimant's Address - City",
            question_text: "CLAIMANT'S ADDRESS - CITY"
          },
          'state' => {
            key: 'form1[0].#subform[82].CurrentMailingAddress_StateOrProvince[0]'
          },
          'country' => {
            key: 'form1[0].#subform[82].CurrentMailingAddress_Country[0]'
          },
          'postalCode' => {
            'firstFive' => {
              key: 'form1[0].#subform[82].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
            },
            'lastFour' => {
              key: 'form1[0].#subform[82].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]',
              limit: 4,
              question_num: 10,
              question_label: "Claimant's Address - Postal Code - Last Four",
              question_text: "CLAIMANT's ADDRESS - POSTAL CODE - LAST FOUR"
            }
          }
        },
        'claimantPhone' => {
          'first' => {
            key: 'form1[0].#subform[82].TelephoneNumber_AreaCode[0]'
          },
          'second' => {
            key: 'form1[0].#subform[82].TelephoneNumber_FirstThreeNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[82].TelephoneNumber_LastFourNumbers[0]'
          }
        },
        'claimantIntPhone' => {
          key: 'form1[0].#subform[94].International_Telephone_Number[0]'
        },
        'claimantEmail' => {
          key: 'form1[0].#subform[82].E-Mail_Address[0]',
          limit: 31,
          question_num: 12,
          question_label: 'E-Mail Address',
          question_text: 'E-MAIL ADDRESS'
        },
        'relationshipToVeteran' => {
          key: 'form1[0].#subform[94].RadioButtonList[0]'
        }
      }.freeze

      ##
      # Expands the form data for Section 2.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        split_postal_code(form_data) # ['claimantAddress']['postalCode']
        extract_middle_i(form_data, 'claimantFullName')
        form_data['claimantDateOfBirth'] = split_date(form_data['claimantDateOfBirth'])
        split_phone(form_data, 'claimantPhone')
        form_data['claimantSocialSecurityNumber'] = split_ssn(form_data['claimantSocialSecurityNumber'])
        relationship_to_veteran = form_data['relationshipToVeteran']
        form_data['relationshipToVeteran'] = Constants::RELATIONSHIPS[relationship_to_veteran]
      end
    end
  end
end
