# frozen_string_literal: true

module PdfFill
  module Forms
    class Va221919 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
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
          question_text: 'DATE SIGNED'
        }
      }.freeze

      def merge_fields(_)
        form_data = @form_data

        # Combine first and last name for certifying official
        if form_data['certifyingOfficial']
          official = form_data['certifyingOfficial']
          official['fullName'] = "#{official['first']} #{official['last']}" if official['first'] && official['last']
          
          # Set display role
          if official['role']
            role = official['role']
            official['role']['displayRole'] = role['level'] == 'other' ? role['other'] : role['level']
          end
        end

        # Convert boolean fields to YES/NO
        form_data['isProprietaryProfit'] = convert_boolean_to_yes_no(form_data['isProprietaryProfit'])
        form_data['isProfitConflictOfInterest'] = convert_boolean_to_yes_no(form_data['isProfitConflictOfInterest'])
        form_data['allProprietaryConflictOfInterest'] = convert_boolean_to_yes_no(form_data['allProprietaryConflictOfInterest'])

        # Process proprietary profit conflicts (max 2)
        if form_data['proprietaryProfitConflicts']
          conflicts = form_data['proprietaryProfitConflicts'].first(2)
          conflicts.each_with_index do |conflict, index|
            form_data["proprietaryProfitConflicts#{index}"] = {
              'employeeName' => "#{conflict['affiliatedIndividuals']['first']} #{conflict['affiliatedIndividuals']['last']}",
              'association' => conflict['affiliatedIndividuals']['individualAssociationType']&.upcase
            }
          end
        end

        # Process all proprietary profit conflicts (max 2)
        if form_data['allProprietaryProfitConflicts']
          conflicts = form_data['allProprietaryProfitConflicts'].first(2)
          conflicts.each_with_index do |conflict, index|
            form_data["allProprietaryProfitConflicts#{index}"] = {
              'officialName' => "#{conflict['certifyingOfficial']['first']} #{conflict['certifyingOfficial']['last']}",
              'fileNumber' => conflict['fileNumber'],
              'enrollmentDateRange' => conflict['enrollmentPeriod']['from'],
              'enrollmentDateRangeEnd' => conflict['enrollmentPeriod']['to']
            }
          end
        end

        form_data
      end

      private

      def convert_boolean_to_yes_no(value)
        return 'N/A' if value.nil?

        value ? 'YES' : 'NO'
      end
    end
  end
end
