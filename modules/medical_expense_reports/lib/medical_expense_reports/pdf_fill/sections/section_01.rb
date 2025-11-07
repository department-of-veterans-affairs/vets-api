# frozen_string_literal: true

require 'medical_expense_reports/pdf_fill/section'

module MedicalExpenseReports
  module PdfFill
    # Section I: Veteran's Identification Information
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
            question_text: 'VETERAN\'S FIRST NAME',
            key: 'form1[0].#subform[9].TextField1[0]'
          },
          'middle' => {
            limit: 1,
            question_num: 1,
            question_suffix: 'A',
            key: 'form1[0].#subform[9].TextField1[1]'
          },
          'last' => {
            limit: 18,
            question_num: 1,
            question_suffix: 'A',
            question_label: "Veteran's Last Name",
            question_text: 'VETERAN\'S LAST NAME',
            key: 'form1[0].#subform[9].TextField1[2]'
          }
        },
        # 1b
        'veteranSocialSecurityNumber' => {
          question_num: 1,
          question_suffix: 'B',
          limit: 9,
          key: 'form1[0].#subform[9].Enter_Veterans_Social_Security_Number[0]'
        },
        # 1c
        'vaFileNumber' => {
          question_num: 1,
          question_suffix: 'C',
          key: 'form1[0].#subform[9].Enter_V_A_File_Number[0]'
        }
      }.freeze

      # expand veteran name
      def expand(form_data = {})
        form_data['veteranFullName'] ||= {}
        form_data['veteranFullName']['first'] = form_data.dig('veteranFullName', 'first')&.titleize
        form_data['veteranFullName']['middle'] = form_data.dig('veteranFullName', 'middle')&.first&.titleize
        form_data['veteranFullName']['last'] = form_data.dig('veteranFullName', 'last')&.titleize
        form_data
      end
    end
  end
end
