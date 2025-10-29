# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section I: Veteran Information
    class Section1 < Section
      # Section configuration hash
      KEY = {
        'veteranFullName' => { # start veteran information
          'first' => {
            key: 'form1[0].#subform[82].VeteransFirstName[0]',
            limit: 12,
            question_num: 1,
            question_label: "Deceased Veteran's First Name",
            question_text: "DECEASED VETERAN'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'form1[0].#subform[82].VeteransMiddleInitial1[0]',
            question_num: 1,
            limit: 1,
            question_label: "Deceased Veteran's Middle Initial",
            question_text: "DECEASED VETERAN'S MIDDLE INITIAL"
          },
          'last' => {
            key: 'form1[0].#subform[82].VeteransLastName[0]',
            limit: 18,
            question_num: 1,
            question_label: "Deceased Veteran's Last Name",
            question_text: "DECEASED VETERAN'S LAST NAME"
          },
          'suffix' => {
            key: 'form1[0].#subform[82].Suffix[0]',
            question_num: 1,
            limit: 0,
            question_label: "Deceased Veteran's Suffix",
            question_text: "DECEASED VETERAN'S SUFFIX"
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[82].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[82].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[82].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'vaFileNumber' => {
          key: 'form1[0].#subform[82].VAFileNumber[0]',
          question_num: 3
        },
        'veteranDateOfBirth' => {
          'month' => {
            key: 'form1[0].#subform[82].Veterans_DOBmonth[0]',
            limit: 2,
            question_num: 4,
            question_suffix: 'A',
            question_label: "Veteran/Claimant's Identification Information > Veteran's Date Of Birth (Mm-Dd-Yyyy)",
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BIRTH (MM-DD-YYYY)'
          },
          'day' => {
            key: 'form1[0].#subform[82].Veterans_DOBday[0]',
            limit: 2,
            question_num: 4,
            question_suffix: 'B',
            question_label: "Veteran/Claimant's Identification Information > Veteran's Date Of Birth (Mm-Dd-Yyyy)",
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BIRTH (MM-DD-YYYY)'
          },
          'year' => {
            key: 'form1[0].#subform[82].Veterans_DOByear[0]',
            limit: 4,
            question_num: 4,
            question_suffix: 'C',
            question_label: "Veteran/Claimant's Identification Information > Veteran's Date Of Birth (Mm-Dd-Yyyy)",
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BIRTH (MM-DD-YYYY)'
          }
        },
        'deathDate' => {
          'month' => {
            key: 'form1[0].#subform[82].Veterans_DateOfDeathmonth[0]',
            limit: 2,
            question_num: 5,
            question_suffix: 'A',
            question_label: "Veteran/Claimant's Identification Information > Veteran's Date Of Death (Mm-Dd-Yyyy)",
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF DEATH (MM-DD-YYYY)'
          },
          'day' => {
            key: 'form1[0].#subform[82].Veterans_DateofDeathday[0]',
            limit: 2,
            question_num: 5,
            question_suffix: 'B',
            question_label: "Veteran/Claimant's Identification Information > Veteran's Date Of Death (Mm-Dd-Yyyy)",
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF DEATH (MM-DD-YYYY)'
          },
          'year' => {
            key: 'form1[0].#subform[82].Veterans_DateofDeathyear[0]',
            limit: 4,
            question_num: 5,
            question_suffix: 'C',
            question_label: "Veteran/Claimant's Identification Information > Veteran's Date Of Death (Mm-Dd-Yyyy)",
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF DEATH (MM-DD-YYYY)'
          }
        },
        'burialDate' => {
          'month' => {
            key: 'form1[0].#subform[82].Veterans_Date_of_Burial_Month[0]',
            limit: 2,
            question_num: 6,
            question_suffix: 'A',
            question_label: "Veteran/Claimant's Identification Information > Veteran's Date Of Burial (Mm-Dd-Yyyy)",
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BURIAL (MM-DD-YYYY)'
          },
          'day' => {
            key: 'form1[0].#subform[82].Veterans_Date_of_Burial_Day[0]',
            limit: 2,
            question_num: 6,
            question_suffix: 'B',
            question_label: "Veteran/Claimant's Identification Information > Veteran's Date Of Burial (Mm-Dd-Yyyy)",
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BURIAL  (MM-DD-YYYY)'
          },
          'year' => {
            key: 'form1[0].#subform[82].Veterans_Date_of_Burial_Year[0]',
            limit: 4,
            question_num: 6,
            question_suffix: 'C',
            question_label: "Veteran/Claimant's Identification Information > Veteran's Date Of Burial (Mm-Dd-Yyyy)",
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BURIAL (MM-DD-YYYY)'
          }
        }
      }.freeze

      ##
      # Expands the form data for Section 1.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        # Add expansion logic here
      end
    end
  end
end
