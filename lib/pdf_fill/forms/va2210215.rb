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
              question_text: 'TOTAL FTE',
              transform: ->(value) { "#{value}%" }
            },
            'supportedPercentageFTE' => {
              key: 'supportedFTE%iterator%',
              limit: 10,
              question_num: 7,
              question_suffix: 'E',
              question_text: 'SUPPORTED PERCENTAGE FTE',
              transform: ->(value) { "#{value}%" }
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

            if program['fte']
              if program['fte']['supportedPercentageFTE'].present?
                program['fte']['supportedPercentageFTE'] = "#{program['fte']['supportedPercentageFTE']}%"
              end
            end
          end
        end

        form_data
      end
    end
  end
end
