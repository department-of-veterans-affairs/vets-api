# frozen_string_literal: true

module PdfFill
  module Forms
    class Va2210215a < FormBase
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
              question_text: 'SUPPORTED STUDENTS',
              transform: ->(value) { value.present? ? format('%.2f', value) : value }
            },
            'nonSupported' => {
              key: 'numNonSupported%iterator%',
              limit: 10,
              question_num: 7,
              question_suffix: 'C',
              question_text: 'NON-SUPPORTED STUDENTS',
              transform: ->(value) { value.present? ? format('%.2f', value) : value }
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
        # Deep copy to avoid modifying original data
        form_data = JSON.parse(JSON.generate(@form_data))

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

            if program['fte'] && program['fte']['supportedPercentageFTE'].present?
              program['fte']['supportedPercentageFTE'] = "#{program['fte']['supportedPercentageFTE']}%"
            end
          end
        end

        # Handle page numbering for continuation sheets
        page_number = options[:page_number] || 1
        total_pages = options[:total_pages] || 1
        form_data['pageNumber'] = "Page #{page_number} of #{total_pages}"
        form_data['totalPages'] = total_pages.to_s

        form_data
      end
    end
  end
end 