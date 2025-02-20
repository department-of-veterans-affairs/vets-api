# frozen_string_literal: true

module PdfFill
  module Forms
    class Va2210216 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'institutionDetails' => {
          'institutionName' => {
            key: 'Text1',
            limit: 50,
            question_num: 1,
            question_suffix: 'A',
            question_text: 'INSTITUTION NAME'
          },
          'facilityCode' => {
            key: 'Text2',
            limit: 8,
            question_num: 2,
            question_suffix: 'A',
            question_text: 'FACILITY CODE'
          },
          'termStartDate' => {
            key: 'Text3',
            limit: 14,
            question_num: 3,
            question_suffix: 'C',
            question_text: 'TERM START DATE'
          }
        },
        'studentRatioCalcChapter' => {
          'beneficiaryStudent' => {
            key: 'Text4',
            limit: 10,
            question_num: 4,
            question_suffix: 'A',
            question_text: 'NUMBER OF VA BENEFICIARY STUDENTS'
          },
          'numOfStudent' => {
            key: 'Text5',
            limit: 10,
            question_num: 5,
            question_suffix: 'A',
            question_text: 'TOTAL NUMBER OF STUDENTS'
          },
          'VABeneficiaryStudentsPercentage' => {
            key: 'Text6',
            limit: 10,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'VA BENEFICIARY STUDENTS PERCENTAGE'
          },
          'dateOfCalculation' => {
            key: 'Text7',
            limit: 20,
            question_num: 7,
            question_suffix: 'C',
            question_text: 'DATE OF CALCULATION'
          }
        }
      }.freeze

      def merge_fields(_)
        @form_data
      end
    end
  end
end
