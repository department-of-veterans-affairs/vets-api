# frozen_string_literal: true

module PdfFill
  module Forms
    class Va2210216 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'institutionDetails' => {
          'institutionName' => {
            key: 'INSTITUTION_NAME[0].#subform[1].F[0]',
            limit: 50,
            question_num: 1,
            question_suffix: 'A',
            question_text: 'INSTITUTION NAME'
          },
          'facilityCode' => {
            key: 'FACILITY_CODE[0].#subform[1].F[0]',
            limit: 8,
            question_num: 2,
            question_suffix: 'A',
            question_text: 'FACILITY CODE'
          },
          'termStartDate' => {
            key: 'TERM_START_DATE[0].#subform[1].F[0]',
            limit: 14,
            question_num: 3,
            question_suffix: 'C',
            question_text: 'TERM START DATE'
          }
        },
        'studentRatioCalcChapter' => {
          'beneficiaryStudent' => {
            key: 'VA_BENEFICIARY_STUDENTS[0].#subform[1].F[0]',
            limit: 10,
            question_num: 4,
            question_suffix: 'A',
            question_text: 'NUMBER OF VA BENEFICIARY STUDENTS'
          },
          'numOfStudent' => {
            key: 'TOTAL_NUMBER_OF_STUDENTS[0].#subform[1].F[0]',
            limit: 10,
            question_num: 5,
            question_suffix: 'A',
            question_text: 'TOTAL NUMBER OF STUDENTS'
          },
          'VABeneficiaryStudentsPercentage' => {
            key: 'VA_BENEFICIARY_STUDENTS_BENEFICIARY[0].#subform[1].F[0]',
            limit: 10,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'VA BENEFICIARY STUDENTS PERCENTAGE'
          },
          'dateOfCalculation' => {
            key: 'Date_Of_Calculation[0].#subform[1].F[0]',
            limit: 20,
            question_num: 7,
            question_suffix: 'C',
            question_text: 'DATE OF CALCULATION'
          }
        },
        'certifyingOfficial' => {
          'fullName' => {
            key: 'SCHOOL_OFFICIAL_PRINTED_NAME[0].#subform[1].F[0]',
            limit: 50,
            question_num: 8,
            question_suffix: 'A',
            question_text: 'CERTIFYING OFFICIAL NAME'
          },
          'title' => {
            key: 'SCHOOL_OFFICIAL_TITLE[0].#subform[1].F[0]',
            limit: 30,
            question_num: 9,
            question_suffix: 'A',
            question_text: 'CERTIFYING OFFICIAL TITLE'
          }
        },
        'statementOfTruthSignature' => {
          key: 'SCHOOL_OFFICIAL_SIGNATURE[0].#subform[1].F[0]',
          limit: 50,
          question_num: 10,
          question_suffix: 'A',
          question_text: 'STATEMENT OF TRUTH SIGNATURE'
        },
        'dateSigned' => {
          key: 'Date_Signed[0].#subform[1].F[0]',
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
