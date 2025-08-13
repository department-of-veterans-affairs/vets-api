# frozen_string_literal: true

module PdfFill
  module Forms
    class Va221919 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        # Institution details section
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

        # Section (1) Proprietary Profit Schools Only
        'proprietaryProfitConflicts' => {
          '[0]' => {
            'affiliatedIndividuals' => {
              'first' => {
                key: 'employeeName0',
                limit: 30,
                question_num: 4,
                question_suffix: 'A',
                question_text: 'EMPLOYEE NAME (FIRST)'
              },
              'last' => {
                key: 'employeeName0',
                limit: 30,
                question_num: 4,
                question_suffix: 'B',
                question_text: 'EMPLOYEE NAME (LAST)',
                combine_with: ['proprietaryProfitConflicts', '[0]', 'affiliatedIndividuals', 'first']
              },
              'title' => {
                key: 'employeeTitle0',
                limit: 50,
                question_num: 5,
                question_suffix: 'A',
                question_text: 'EMPLOYEE TITLE'
              },
              'individualAssociationType' => {
                key: 'association0',
                limit: 20,
                question_num: 6,
                question_suffix: 'A',
                question_text: 'ASSOCIATION TYPE'
              }
            }
          },
          '[1]' => {
            'affiliatedIndividuals' => {
              'first' => {
                key: 'employeeName1',
                limit: 30,
                question_num: 7,
                question_suffix: 'A',
                question_text: 'EMPLOYEE NAME (FIRST)'
              },
              'last' => {
                key: 'employeeName1',
                limit: 30,
                question_num: 7,
                question_suffix: 'B',
                question_text: 'EMPLOYEE NAME (LAST)',
                combine_with: ['proprietaryProfitConflicts', '[1]', 'affiliatedIndividuals', 'first']
              },
              'title' => {
                key: 'employeeTitle1',
                limit: 50,
                question_num: 8,
                question_suffix: 'A',
                question_text: 'EMPLOYEE TITLE'
              },
              'individualAssociationType' => {
                key: 'association1',
                limit: 20,
                question_num: 9,
                question_suffix: 'A',
                question_text: 'ASSOCIATION TYPE'
              }
            }
          }
        },

        # Section (2) All Proprietary Schools
        'allProprietaryProfitConflicts' => {
          '[0]' => {
            'certifyingOfficial' => {
              'first' => {
                key: 'official0',
                limit: 30,
                question_num: 10,
                question_suffix: 'A',
                question_text: 'OFFICIAL NAME (FIRST)'
              },
              'last' => {
                key: 'official0',
                limit: 30,
                question_num: 10,
                question_suffix: 'B',
                question_text: 'OFFICIAL NAME (LAST)',
                combine_with: ['allProprietaryProfitConflicts', '[0]', 'certifyingOfficial', 'first']
              },
              'title' => {
                key: 'officialTitle0',
                limit: 50,
                question_num: 11,
                question_suffix: 'A',
                question_text: 'OFFICIAL TITLE'
              }
            },
            'fileNumber' => {
              key: 'fileNumber0',
              limit: 15,
              question_num: 12,
              question_suffix: 'A',
              question_text: 'VA FILE NUMBER'
            },
            'enrollmentPeriod' => {
              'from' => {
                key: 'dateStart0',
                limit: 10,
                question_num: 13,
                question_suffix: 'A',
                question_text: 'ENROLLMENT START DATE',
                format: 'date'
              },
              'to' => {
                key: 'dateEnd0',
                limit: 10,
                question_num: 13,
                question_suffix: 'B',
                question_text: 'ENROLLMENT END DATE',
                format: 'date'
              }
            }
          },
          '[1]' => {
            'certifyingOfficial' => {
              'first' => {
                key: 'official1',
                limit: 30,
                question_num: 14,
                question_suffix: 'A',
                question_text: 'OFFICIAL NAME (FIRST)'
              },
              'last' => {
                key: 'official1',
                limit: 30,
                question_num: 14,
                question_suffix: 'B',
                question_text: 'OFFICIAL NAME (LAST)',
                combine_with: ['allProprietaryProfitConflicts', '[1]', 'certifyingOfficial', 'first']
              },
              'title' => {
                key: 'officialTitle1',
                limit: 50,
                question_num: 15,
                question_suffix: 'A',
                question_text: 'OFFICIAL TITLE'
              }
            },
            'fileNumber' => {
              key: 'fileNumber1',
              limit: 15,
              question_num: 16,
              question_suffix: 'A',
              question_text: 'VA FILE NUMBER'
            },
            'enrollmentPeriod' => {
              'from' => {
                key: 'dateStart1',
                limit: 10,
                question_num: 17,
                question_suffix: 'A',
                question_text: 'ENROLLMENT START DATE',
                format: 'date'
              },
              'to' => {
                key: 'dateEnd1',
                limit: 10,
                question_num: 17,
                question_suffix: 'B',
                question_text: 'ENROLLMENT END DATE',
                format: 'date'
              }
            }
          }
        },

        # Certification section
        'certifyingOfficial' => {
          'first' => {
            key: 'certifyingOfficialName',
            limit: 50,
            question_num: 18,
            question_suffix: 'A',
            question_text: 'CERTIFYING OFFICIAL NAME (FIRST)'
          },
          'last' => {
            key: 'certifyingOfficialName',
            limit: 50,
            question_num: 18,
            question_suffix: 'B',
            question_text: 'CERTIFYING OFFICIAL NAME (LAST)',
            combine_with: ['certifyingOfficial', 'first']
          },
          'role' => {
            'level' => {
              key: 'certifyingOfficialTitle',
              limit: 50,
              question_num: 19,
              question_suffix: 'A',
              question_text: 'CERTIFYING OFFICIAL TITLE'
            },
            'other' => {
              key: 'certifyingOfficialTitle',
              limit: 50,
              question_num: 19,
              question_suffix: 'B',
              question_text: 'CERTIFYING OFFICIAL TITLE (OTHER)'
            }
          }
        },

        'statementOfTruthSignature' => {
          key: 'certifyingOfficialSignature',
          limit: 50,
          question_num: 20,
          question_suffix: 'A',
          question_text: 'SIGNATURE'
        },

        'dateSigned' => {
          key: 'dateSigned',
          limit: 10,
          question_num: 21,
          question_suffix: 'A',
          question_text: 'DATE SIGNED',
          format: 'date'
        }
      }.freeze

      def merge_fields(_)
        form_data = @form_data

        # Combine certifying official first and last name
        if form_data['certifyingOfficial']
          official = form_data['certifyingOfficial']
          if official['first'] && official['last']
            official['fullName'] = "#{official['first']} #{official['last']}"
          end

          # Handle role field - if 'other' is selected, use the other value, otherwise use level
          if official['role']
            role = official['role']
            if role['level'] == 'other' && role['other']
              official['roleDisplay'] = role['other']
            else
              official['roleDisplay'] = role['level']&.titleize
            end
          end
        end

        # Handle institution address formatting
        if form_data['institutionDetails'] && form_data['institutionDetails']['institutionAddress']
          address = form_data['institutionDetails']['institutionAddress']
          address_parts = []
          address_parts << address['street'] if address['street']
          address_parts << address['street2'] if address['street2']
          
          city_state_zip = []
          city_state_zip << address['city'] if address['city']
          city_state_zip << address['state'] if address['state']
          city_state_zip << address['postalCode'] if address['postalCode']
          
          address_parts << city_state_zip.join(', ') if city_state_zip.any?
          
          form_data['institutionDetails']['institutionAddress']['formatted'] = address_parts.join("\n")
        end

        # Transform array fields to handle multiple entries
        transform_proprietary_conflicts(form_data)
        transform_all_proprietary_conflicts(form_data)

        form_data
      end

      private

      def transform_proprietary_conflicts(form_data)
        return unless form_data['proprietaryProfitConflicts']

        form_data['proprietaryProfitConflicts'].each_with_index do |conflict, index|
          next unless conflict['affiliatedIndividuals']

          individual = conflict['affiliatedIndividuals']
          
          # Combine first and last name
          if individual['first'] && individual['last']
            individual['fullName'] = "#{individual['first']} #{individual['last']}"
          end

          # Transform association type to display format
          if individual['individualAssociationType']
            individual['associationDisplay'] = individual['individualAssociationType'].upcase
          end
        end
      end

      def transform_all_proprietary_conflicts(form_data)
        return unless form_data['allProprietaryProfitConflicts']

        form_data['allProprietaryProfitConflicts'].each_with_index do |conflict, index|
          next unless conflict['certifyingOfficial']

          official = conflict['certifyingOfficial']
          
          # Combine first and last name
          if official['first'] && official['last']
            official['fullName'] = "#{official['first']} #{official['last']}"
          end

          # Format enrollment period dates
          if conflict['enrollmentPeriod']
            period = conflict['enrollmentPeriod']
            if period['from']
              conflict['enrollmentFromFormatted'] = format_date(period['from'])
            end
            if period['to']
              conflict['enrollmentToFormatted'] = format_date(period['to'])
            end
          end
        end
      end

      def format_date(date_string)
        return date_string unless date_string.is_a?(String)

        begin
          date = Date.parse(date_string)
          date.strftime('%m/%d/%Y')
        rescue ArgumentError
          date_string
        end
      end
    end
  end
end