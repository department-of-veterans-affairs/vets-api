# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section I: Veteran Informations
    class Section1 < Section
      # Section configuration hash with overflow metadata
      KEY = {
        # 1a: Veteran full name
        'veteranFullName' => {
          'first' => {
            key: 'F[0].Page_4[0].VeteransName.First[0]',
            limit: 30,
            question_num: 1,
            question_suffix: 'A',
            question_text: 'Veterans name – first',
            question_label: 'First'
          },
          'middle' => {
            key: 'F[0].Page_4[0].VeteransName.MI[0]',
            limit: 1,
            question_num: 1,
            question_suffix: 'B',
            question_text: 'Veterans name – middle initial',
            question_label: 'MI'
          },
          'last' => {
            key: 'F[0].Page_4[0].VeteransName.Last[0]',
            limit: 30,
            question_num: 1,
            question_suffix: 'C',
            question_text: 'Veterans name – last',
            question_label: 'Last'
          }
        },
        # 1b: Veteran SSN
        'veteranSocialSecurityNumber' => {
          key: 'F[0].Page_4[0].VeteransSSN[0]',
          limit: 9,
          question_num: 2,
          question_text: 'Veterans social security number',
          question_label: 'SSN'
        },
        # 1c: VA file number
        'vaFileNumber' => {
          key: 'F[0].Page_4[0].VeteransFileNumber[0]',
          limit: 20,
          question_num: 3,
          question_text: 'Veterans file number',
          question_label: 'File number'
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
        veteran_middle_name = form_data['veteranFullName'].try(:[], 'middle')
        form_data['veteranFullName']['middle'] = veteran_middle_name.try(:[], 0)&.upcase
      end
    end
  end
end
