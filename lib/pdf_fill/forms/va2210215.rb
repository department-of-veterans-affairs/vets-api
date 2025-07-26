# frozen_string_literal: true

module PdfFill
  module Forms
    class Va2210215 < FormBase
      include FormHelper

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
        'checkbox' => {
          key: 'checkbox',
          limit: 10,
          question_num: 10,
          question_suffix: 'A',
          question_text: 'EXTENSIONS ATTACHED CHECKBOX'
        }
      }.freeze

      def merge_fields(_options = {})
        form_data = JSON.parse(JSON.generate(@form_data))

        combine_official_name(form_data)
        process_programs(form_data)

        form_data
      end

      private

      def combine_official_name(form_data)
        official = form_data['certifyingOfficial']
        return unless official

        official['fullName'] = "#{official['first']} #{official['last']}" if official['first'] && official['last']
      end

      def process_programs(form_data)
        return unless form_data['programs']

        calculation_date = form_data.dig('institutionDetails', 'dateOfCalculations')

        form_data['programs'].each do |program|
          program['programDateOfCalculation'] = calculation_date if calculation_date
          process_fte(program['fte']) if program['fte']
        end
      end

      def process_fte(fte)
        fte['supported'] = format_zero_as(fte['supported'], '--')
        fte['nonSupported'] = format_zero_as(fte['nonSupported'], '--')
        fte['totalFTE'] = format_zero_as(fte['totalFTE'], '--')
        fte['supportedPercentageFTE'] = format_zero_as(fte['supportedPercentageFTE'], 'N/A')
      end
    end
  end
end
