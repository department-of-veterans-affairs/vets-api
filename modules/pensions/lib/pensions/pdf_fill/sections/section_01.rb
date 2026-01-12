# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section I: Veteran Information
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
      # Expands and normalizes the veteran's information by:
      # - Titleizing the first, middle, and last names
      # - Splitting the Social Security Number into its components
      # - Splitting the Date of Birth into month, day, and year
      # - Converting vaClaimsHistory to radio button format
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        form_data['veteranFullName'] ||= {}
        form_data['veteranFullName'] = expand_full_name(form_data['veteranFullName'] || {})
        form_data['veteranSocialSecurityNumber'] = split_ssn(form_data['veteranSocialSecurityNumber'])
        form_data['veteranDateOfBirth'] = split_date(form_data['veteranDateOfBirth'])
        form_data['vaClaimsHistory'] = to_radio_yes_no(form_data['vaClaimsHistory'])
      end

      ##
      # Titleizes the veteran's full name and extracts the middle initial.
      # @param full_name [Hash]
      #
      # @return [Hash] The modified full_name hash with titleized names and middle initial
      #
      def expand_full_name(full_name)
        middle_initial = full_name['middle']&.first || '' # Get middle initial

        full_name['first'] = full_name['first']&.titleize
        full_name['middle'] = middle_initial&.upcase
        full_name['last'] = full_name['last']&.titleize

        full_name
      end
    end
  end
end
