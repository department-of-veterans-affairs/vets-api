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
            key: 'termStartDate',
            limit: 10,
            question_num: 3,
            question_suffix: 'A',
            question_text: 'TERM START DATE'
          },
          'dateOfCalculations' => {
            key: 'institutionDateOfCalculations',
            limit: 10,
            question_num: 4,
            question_suffix: 'A',
            question_text: 'DATE OF CALCULATIONS'
          }
        },
        'certifyingOfficial' => {
          'fullName' => {
            key: 'fullName',
            limit: 50,
            question_num: 5,
            question_suffix: 'A',
            question_text: 'CERTIFYING OFFICIAL NAME'
          },
          'title' => {
            key: 'title',
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
            key: 'programName[%iterator%]',
            limit: 50,
            question_num: 7,
            question_suffix: 'A',
            question_text: 'PROGRAM NAME'
          },
          'fte' => {
            'supported' => {
              key: 'supportedStudents[%iterator%]',
              limit: 10,
              question_num: 7,
              question_suffix: 'B',
              question_text: 'SUPPORTED STUDENTS'
            },
            'nonSupported' => {
              key: 'nonSupportedStudents[%iterator%]',
              limit: 10,
              question_num: 7,
              question_suffix: 'C',
              question_text: 'NON-SUPPORTED STUDENTS'
            },
            'totalFTE' => {
              key: 'totalFTE[%iterator%]',
              limit: 10,
              question_num: 7,
              question_suffix: 'D',
              question_text: 'TOTAL FTE'
            },
            'supportedPercentageFTE' => {
              key: 'supportedPercentageFTE[%iterator%]',
              limit: 10,
              question_num: 7,
              question_suffix: 'E',
              question_text: 'SUPPORTED PERCENTAGE FTE'
            }
          },
          'programDateOfCalculation' => {
            key: 'dateOfCalculation[%iterator%]',
            limit: 10,
            question_num: 7,
            question_suffix: 'F',
            question_text: 'PROGRAM DATE OF CALCULATION'
          }
        },
        'statementOfTruthSignature' => {
          key: 'statementOfTruthSignature',
          limit: 50,
          question_num: 8,
          question_suffix: 'A',
          question_text: 'STATEMENT OF TRUTH SIGNATURE'
        },
        'dateSigned' => {
          key: 'dateSigned',
          limit: 10,
          question_num: 9,
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

        # Process programs array - add programDateOfCalculation for each valid row
        if form_data['programs'] && form_data['institutionDetails'] &&
           form_data['institutionDetails']['dateOfCalculations']
          calculation_date = form_data['institutionDetails']['dateOfCalculations']

          form_data['programs'].each do |program|
            # Add programDateOfCalculation to each valid program entry
            program['programDateOfCalculation'] = calculation_date
          end
        end

        form_data
      end
    end
  end
end
