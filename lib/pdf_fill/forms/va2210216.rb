# frozen_string_literal: true

module PdfFill
  module Forms
    class Va2210216 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'institutionDetails' => {
          'institutionName' => {
            key: 'F[0].#subform[1].INSTITUTION_NAME[0]',
            limit: 50,
            question_num: 1,
            question_suffix: 'A',
            question_text: 'INSTITUTION NAME'
          },
          'facilityCode' => {
            key: 'F[0].#subform[1].FACILITY_CODE[0]',
            limit: 8,
            question_num: 2,
            question_suffix: 'A',
            question_text: 'FACILITY CODE'
          },
          'termStartDate' => {
            key: 'F[0].#subform[1].TERM_START_DATE[0]',
            limit: 14,
            question_num: 3,
            question_suffix: 'C',
            question_text: 'TERM START DATE'
          }
        },
        'studentRatioCalcChapter' => {
          'beneficiaryStudent' => {
            key: 'F[0].#subform[1].VA_BENEFICIARY_STUDENTS[0]',
            limit: 10,
            question_num: 4,
            question_suffix: 'A',
            question_text: 'NUMBER OF VA BENEFICIARY STUDENTS'
          },
          'numOfStudent' => {
            key: 'F[0].#subform[1].TOTAL_NUMBER_OF_STUDENTS[0]',
            limit: 10,
            question_num: 5,
            question_suffix: 'A',
            question_text: 'TOTAL NUMBER OF STUDENTS'
          },
          'VABeneficiaryStudentsPercentage' => {
            key: 'F[0].#subform[1].VA_BENEFICIARY_STUDENTS_BENEFICIARY[0]',
            limit: 10,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'VA BENEFICIARY STUDENTS PERCENTAGE'
          },
          'dateOfCalculation' => {
            key: 'F[0].#subform[1].Date_Of_Calculation[0]',
            limit: 20,
            question_num: 7,
            question_suffix: 'C',
            question_text: 'DATE OF CALCULATION'
          }
        },
        'certifyingOfficial' => {
          'fullName' => {
            key: 'F[0].#subform[1].SCHOOL_OFFICIAL_PRINTED_NAME[0]',
            limit: 50,
            question_num: 8,
            question_suffix: 'A',
            question_text: 'CERTIFYING OFFICIAL NAME'
          },
          'title' => {
            key: 'F[0].#subform[1].SCHOOL_OFFICIAL_TITLE[0]',
            limit: 30,
            question_num: 9,
            question_suffix: 'A',
            question_text: 'CERTIFYING OFFICIAL TITLE'
          }
        },
        'statementOfTruthSignature' => {
          key: 'F[0].#subform[1].SCHOOL_OFFICIAL_PRINTED_NAME[0]',
          limit: 50,
          question_num: 10,
          question_suffix: 'A',
          question_text: 'STATEMENT OF TRUTH SIGNATURE'
        },
        'dateSigned' => {
          key: 'F[0].#subform[1].Date_Signed[0]',
          limit: 10,
          question_num: 11,
          question_suffix: 'A',
          question_text: 'DATE SIGNED'
        }
      }.freeze

      def merge_fields(_)
        form_data = @form_data

        # Combine first and last name into fullName
        if form_data['certifyingOfficial']
          official = form_data['certifyingOfficial']
          official['fullName'] = "#{official['first']} #{official['last']}" if official['first'] && official['last']
        end

        form_data
      end
    end
  end
end
