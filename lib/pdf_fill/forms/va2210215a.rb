# frozen_string_literal: true

require 'pdf_fill/forms/formatters/va2210215'

module PdfFill
  module Forms
    class Va2210215a < FormBase
      include FormHelper

      FORMATTER = PdfFill::Forms::Formatters::Va2210215
      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'institutionDetails' => {
          'institutionName' => {
            key: 'institutionName',
            limit: 50,
            question_num: 1,
            question_suffix: 'A',
            question_text: 'INSTITUTION NAME'
          },
          'facilityCode' => {
            key: 'facilityCode',
            limit: 8,
            question_num: 2,
            question_suffix: 'A',
            question_text: 'FACILITY CODE'
          },
          'termStartDate' => {
            key: 'startDate',
            limit: 10,
            question_num: 3,
            question_suffix: 'A',
            question_text: 'TERM START DATE'
          },
          'dateOfCalculations' => {
            key: 'calculationDate',
            limit: 10,
            question_num: 4,
            question_suffix: 'A',
            question_text: 'DATE OF CALCULATIONS'
          }
        },
        'certifyingOfficial' => {
          'fullName' => {
            key: 'scoName',
            limit: 50,
            question_num: 5,
            question_suffix: 'A',
            question_text: 'CERTIFYING OFFICIAL NAME'
          },
          'title' => {
            key: 'scoTitle',
            limit: 30,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'CERTIFYING OFFICIAL TITLE'
          }
        },
        'programs' => {
          limit: 16,
          first_key: 'programName',
          'programName' => {
            key: 'programName%iterator%',
            limit: 50,
            question_num: 7,
            question_suffix: 'A',
            question_text: 'PROGRAM NAME'
          },
          'studentsEnrolled' => {
            key: 'totalEnrolled%iterator%',
            limit: 10,
            question_num: 7,
            question_suffix: 'B',
            question_text: 'TOTAL NUMBER OF STUDENTS ENROLLED'
          },
          'supportedStudents' => {
            key: 'supportedEnrolled%iterator%',
            limit: 10,
            question_num: 7,
            question_suffix: 'B',
            question_text: 'SUPPORTED STUDENTS'
          },
          'fte' => {
            'supported' => {
              key: 'numSupported%iterator%',
              limit: 10,
              question_num: 7,
              question_suffix: 'B',
              question_text: 'SUPPORTED STUDENTS'
            },
            'nonSupported' => {
              key: 'numNonSupported%iterator%',
              limit: 10,
              question_num: 7,
              question_suffix: 'C',
              question_text: 'NON-SUPPORTED STUDENTS'
            },
            'totalFTE' => {
              key: 'enrolledFTE%iterator%',
              limit: 10,
              question_num: 7,
              question_suffix: 'D',
              question_text: 'TOTAL FTE'
            },
            'supportedPercentageFTE' => {
              key: 'supportedFTE%iterator%',
              limit: 10,
              question_num: 7,
              question_suffix: 'E',
              question_text: 'SUPPORTED PERCENTAGE FTE'
            }
          },
          'programDateOfCalculation' => {
            key: 'calculationDate%iterator%',
            limit: 10,
            question_num: 7,
            question_suffix: 'F',
            question_text: 'PROGRAM DATE OF CALCULATION'
          }
        },
        'statementOfTruthSignature' => {
          key: 'signature',
          limit: 50,
          question_num: 8,
          question_suffix: 'A',
          question_text: 'STATEMENT OF TRUTH SIGNATURE'
        },
        'dateSigned' => {
          key: 'signedDate',
          limit: 10,
          question_num: 9,
          question_suffix: 'A',
          question_text: 'DATE SIGNED'
        },
        'pageNumber' => {
          key: 'pageNumber',
          limit: 20,
          question_num: 10,
          question_suffix: 'A',
          question_text: 'PAGE NUMBER'
        },
        'totalPages' => {
          key: 'totalPages',
          limit: 10,
          question_num: 11,
          question_suffix: 'A',
          question_text: 'TOTAL PAGES'
        }
      }.freeze

      def merge_fields(options = {})
        form_data = JSON.parse(JSON.generate(@form_data))

        FORMATTER.combine_official_name(form_data)
        FORMATTER.process_programs(form_data)
        handle_page_numbering(form_data, options)

        form_data
      end

      private

      def handle_page_numbering(form_data, options)
        page_number = options[:page_number] || 1
        total_pages = options[:total_pages] || 1
        form_data['pageNumber'] = page_number.to_s
        form_data['totalPages'] = total_pages.to_s
      end
    end
  end
end
