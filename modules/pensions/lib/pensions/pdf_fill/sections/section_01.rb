# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section I: Veteran Informations
    class Section1 < Section
      # Section configuration hash
      KEY = {
        # 1a
        'veteranFullName' => {
          'first' => {
            limit: 12,
            question_num: 1,
            question_suffix: 'A',
            question_label: "Veteran's First Name",
            question_text: "VETERAN'S FIRST NAME",
            key: 'form1[0].#subform[48].VeteransFirstName[0]'
          },
          'middle' => {
            key: 'form1[0].#subform[48].VeteransMiddleInitial1[0]'
          },
          'last' => {
            limit: 18,
            question_num: 1,
            question_suffix: 'A',
            question_label: "Veteran's Last Name",
            question_text: "VETERAN'S LAST NAME",
            key: 'form1[0].#subform[48].VeteransLastName[0]'
          }
        },
        # 1b
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[48].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[48].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[48].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        # 1c
        'veteranDateOfBirth' => {
          'month' => {
            key: 'form1[0].#subform[48].DOBmonth[0]'
          },
          'day' => {
            key: 'form1[0].#subform[48].DOBday[0]'
          },
          'year' => {
            key: 'form1[0].#subform[48].DOByear[0]'
          }
        },
        # 1d
        'vaClaimsHistory' => {
          key: 'form1[0].#subform[48].RadioButtonList[0]'
        },
        # 1e
        'vaFileNumber' => {
          key: 'form1[0].#subform[48].VAFileNumber[0]'
        }
      }.freeze

      ##
      # Expands the veteran's information by extracting and capitalizing the first letter of the middle name.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        form_data['veteranFullName'] ||= {}
        form_data['veteranFullName']['first'] = form_data.dig('veteranFullName', 'first')&.titleize
        form_data['veteranFullName']['middle'] = form_data.dig('veteranFullName', 'middle')&.titleize
        form_data['veteranFullName']['last'] = form_data.dig('veteranFullName', 'last')&.titleize
        form_data['veteranSocialSecurityNumber'] = split_ssn(form_data['veteranSocialSecurityNumber'])
        form_data['veteranDateOfBirth'] = split_date(form_data['veteranDateOfBirth'])
        form_data['vaClaimsHistory'] = to_radio_yes_no(form_data['vaClaimsHistory'])
      end
    end
  end
end
