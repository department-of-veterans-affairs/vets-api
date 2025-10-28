# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section IV: Final Resting Place Information
    class Section4 < Section
      # rubocop:disable Layout/LineLength
      # Section configuration hash
      KEY = {
        'veteranSocialSecurityNumber2' => {
          'first' => {
            key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_FirstThreeNumbers[1]'
          },
          'second' => {
            key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_SecondTwoNumbers[1]'
          },
          'third' => {
            key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_LastFourNumbers[1]'
          }
        },
        # 16
        'finalRestingPlace' => { # break into yes/nos
          'location' => {
            'cemetery' => {
              key: 'form1[0].#subform[83].#subform[84].RestingPlaceCemetery[5]'
            },
            'privateResidence' => {
              key: 'form1[0].#subform[83].#subform[84].RestingPlacePrivateResidence[5]'
            },
            'mausoleum' => {
              key: 'form1[0].#subform[83].#subform[84].RestingPlaceMausoleum[5]'
            },
            'other' => {
              key: 'form1[0].#subform[83].#subform[84].RestingPlaceOther[5]'
            }
          },
          'other' => {
            limit: 58,
            question_num: 16,
            question_label: "Place Of Burial Plot, Interment Site, Or Final Resting Place Of Deceased Veteran's Remains",
            question_text: "PLACE OF BURIAL PLOT, INTERMENT SITE, OR FINAL RESTING PLACE OF DECEASED VETERAN'S REMAINS",
            key: 'form1[0].#subform[83].#subform[84].PLACE_OF_DEATH[0]'
          }
        },
        # 17
        'hasNationalOrFederal' => {
          key: 'form1[0].#subform[37].FederalCemetery[0]'
        },
        'name' => {
          key: 'form1[0].#subform[37].FederalCemeteryName[0]',
          limit: 50
        },
        # 18
        'cemetaryLocationQuestionCemetery' => {
          key: 'form1[0].#subform[37].HasStateCemetery[2]'
        },
        'cemetaryLocationQuestionTribal' => {
          key: 'form1[0].#subform[37].HasTribalTrust[2]'
        },
        'cemetaryLocationQuestionNone' => {
          key: 'form1[0].#subform[37].NoStateCemetery[2]'
        },
        'stateCemeteryOrTribalTrustName' => {
          key: 'form1[0].#subform[37].StateCemeteryOrTribalTrustName[2]',
          limit: 33
        },
        'stateCemeteryOrTribalTrustZip' => {
          key: 'form1[0].#subform[37].StateCemeteryOrTribalTrustZip[2]'
        },
        # 19A
        'hasGovtContributions' => {
          key: 'form1[0].#subform[37].GovContribution[0]'
        },
        # 19B
        'amountGovtContribution' => {
          key: 'form1[0].#subform[37].AmountGovtContribution[0]',
          question_num: 19,
          question_suffix: 'B',
          dollar: true,
          question_label: 'Amount Of Government Or Employer Contribution',
          question_text: 'AMOUNT OF GOVERNMENT OR EMPLOYER CONTRIBUTION',
          limit: 5
        }
      }.freeze
      # rubocop:emable Layout/LineLength

      ##
      # Expands the form data for Section 4.
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
