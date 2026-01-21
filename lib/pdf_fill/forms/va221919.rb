# frozen_string_literal: true

require 'pdf_fill/forms/formatters/va221919'

module PdfFill
  module Forms
    class Va221919 < FormBase
      include FormHelper

      FORMATTER = PdfFill::Forms::Formatters::Va221919
      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'isAuthenticated' => {
          key: 'isAuthenticated',
          limit: 1,
          question_num: 23,
          question_suffix: 'A',
          question_text: 'IS AUTHENTICATED'
        },
        'institutionDetails' => {
          'institutionName' => {
            key: 'institutionName',
            limit: 100,
            question_num: 1,
            question_suffix: 'A',
            question_text: 'INSTITUTION NAME'
          },
          'institutionAddress' => {
            'street' => {
              key: 'institutionAddress',
              limit: 100,
              question_num: 2,
              question_suffix: 'A',
              question_text: 'INSTITUTION ADDRESS'
            }
          },
          'facilityCode' => {
            key: 'facilityCode',
            limit: 8,
            question_num: 3,
            question_suffix: 'A',
            question_text: 'FACILITY CODE'
          }
        },
        'certifyingOfficial' => {
          'fullName' => {
            key: 'certifyingOfficialName',
            limit: 60,
            question_num: 4,
            question_suffix: 'A',
            question_text: 'CERTIFYING OFFICIAL NAME'
          },
          'role' => {
            'displayRole' => {
              key: 'certifyingOfficialTitle',
              limit: 50,
              question_num: 5,
              question_suffix: 'A',
              question_text: 'CERTIFYING OFFICIAL TITLE'
            }
          }
        },
        'isProprietaryProfit' => {
          key: 'isProprietaryProfit',
          limit: 3,
          question_num: 6,
          question_suffix: 'A',
          question_text: 'IS PROPRIETARY PROFIT'
        },
        'isProfitConflictOfInterest' => {
          key: 'isProfitConflictOfInterest',
          limit: 3,
          question_num: 7,
          question_suffix: 'A',
          question_text: 'IS PROFIT CONFLICT OF INTEREST'
        },
        'proprietaryProfitConflicts0' => {
          'employeeName' => {
            key: 'employeeName0',
            limit: 60,
            question_num: 8,
            question_suffix: 'A',
            question_text: 'EMPLOYEE NAME 0'
          },
          'association' => {
            key: 'association0',
            limit: 30,
            question_num: 9,
            question_suffix: 'A',
            question_text: 'ASSOCIATION 0'
          }
        },
        'proprietaryProfitConflicts1' => {
          'employeeName' => {
            key: 'employeeName1',
            limit: 60,
            question_num: 10,
            question_suffix: 'A',
            question_text: 'EMPLOYEE NAME 1'
          },
          'association' => {
            key: 'association1',
            limit: 30,
            question_num: 11,
            question_suffix: 'A',
            question_text: 'ASSOCIATION 1'
          }
        },
        'allProprietaryConflictOfInterest' => {
          key: 'allProprietaryConflictOfInterest',
          limit: 3,
          question_num: 12,
          question_suffix: 'A',
          question_text: 'ALL PROPRIETARY CONFLICT OF INTEREST'
        },
        'allProprietaryProfitConflicts0' => {
          'officialName' => {
            key: 'official0',
            limit: 60,
            question_num: 13,
            question_suffix: 'A',
            question_text: 'OFFICIAL NAME 0'
          },
          'fileNumber' => {
            key: 'fileNumber0',
            limit: 20,
            question_num: 14,
            question_suffix: 'A',
            question_text: 'FILE NUMBER 0'
          },
          'enrollmentDateRange' => {
            key: 'dateStart0',
            limit: 10,
            question_num: 15,
            question_suffix: 'A',
            question_text: 'ENROLLMENT DATE START 0'
          },
          'enrollmentDateRangeEnd' => {
            key: 'dateEnd0',
            limit: 10,
            question_num: 16,
            question_suffix: 'A',
            question_text: 'ENROLLMENT DATE END 0'
          }
        },
        'allProprietaryProfitConflicts1' => {
          'officialName' => {
            key: 'official1',
            limit: 60,
            question_num: 17,
            question_suffix: 'A',
            question_text: 'OFFICIAL NAME 1'
          },
          'fileNumber' => {
            key: 'fileNumber1',
            limit: 20,
            question_num: 18,
            question_suffix: 'A',
            question_text: 'FILE NUMBER 1'
          },
          'enrollmentDateRange' => {
            key: 'dateStart1',
            limit: 10,
            question_num: 19,
            question_suffix: 'A',
            question_text: 'ENROLLMENT DATE START 1'
          },
          'enrollmentDateRangeEnd' => {
            key: 'dateEnd1',
            limit: 10,
            question_num: 20,
            question_suffix: 'A',
            question_text: 'ENROLLMENT DATE END 1'
          }
        },
        'statementOfTruthSignature' => {
          key: 'certifyingOfficialName',
          limit: 60,
          question_num: 21,
          question_suffix: 'A',
          question_text: 'STATEMENT OF TRUTH SIGNATURE'
        },
        'dateSigned' => {
          key: 'dateSigned',
          limit: 10,
          question_num: 22,
          question_suffix: 'A',
          question_text: 'DATE SIGNED',
          format: 'date'
        }
      }.freeze

      def merge_fields(_options = {})
        form_data = JSON.parse(JSON.generate(@form_data))

        FORMATTER.process_certifying_official(form_data)
        FORMATTER.process_institution_address(form_data)
        FORMATTER.convert_boolean_fields(form_data)
        FORMATTER.process_proprietary_conflicts(form_data)
        FORMATTER.process_all_proprietary_conflicts(form_data)
        FORMATTER.process_is_authenticated(form_data)

        form_data
      end
    end
  end
end
