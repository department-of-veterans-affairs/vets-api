# frozen_string_literal: true

module PdfFill
  module Forms
    class Va220839 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR
      AGREEMENT_TYPES = {
        'startNewOpenEndedAgreement' => 'New open-ended agreement',
        'modifyExistingAgreement' => 'Modification to existing agreement',
        'withdrawFromYellowRibbonProgram' => 'Withdrawl of Yellow Ribbon agreement'
      }.freeze

      KEY = {
        'primaryInstitution' => {
          'institutionName' => {
            key: 'institution_name'
          },
          'institutionAddress' => {
            key: 'institution_address'
          },
          'facilityCode' => {
            key: 'institution_facility_code'
          }
        },
        'branchCampuses' => {
          limit: 4,
          'nameAndAddress' => {
            key: "branch_campus_#{ITERATOR}_name"
          },
          'facilityCode' => {
            key: "branch_campus_#{ITERATOR}_facility_code"
          }
        },
        'agreementType' => {
          key: 'agreement_type'
        },
        'numEligibleStudents' => {
          key: 'num_eligible_students'
        },
        'academicYear' => {
          key: 'academic_year'
        },
        'yellowRibbonProgramTerms' => {
          'firstAcknowledgement' => {
            key: 'terms_initials_1'
          },
          'secondAcknowledgement' => {
            key: 'terms_initials_2'
          },
          'thirdAcknowledgement' => {
            key: 'terms_initials_3'
          },
          'fourthAcknowledgement' => {
            key: 'terms_initials_4'
          }
        },
        'pointOfContact' => {
          'fullName' => {
            key: 'poc_name'
          },
          'phoneNumber' => {
            key: 'poc_phone'
          },
          'emailAddress' => {
            key: 'poc_email'
          }
        },
        'pointOfContactTwo' => {
          'fullName' => {
            key: 'sco_name'
          },
          'phoneNumber' => {
            key: 'sco_phone'
          },
          'emailAddress' => {
            key: 'sco_email'
          }
        },
        'authorizedOfficial' => {
          'fullName' => {
            key: 'ao_name'
          },
          'title' => {
            key: 'ao_title'
          },
          'phoneNumber' => {
            key: 'ao_phone'
          }
        },
        'statementOfTruthSignature' => {
          key: 'ao_signature'
        },
        'dateSigned' => {
          key: 'date_signed'
        },
        'authenticatedUser' => {
          key: 'authenticated_user_statement'
        },
        'usSchools' => {
          limit: 11,
          label_all: true,
          'maximumNumberofStudents' => {
            key: "us_school_#{ITERATOR}_max_students"
          },
          'degreeLevel' => {
            key: "us_school_#{ITERATOR}_degree_level"
          },
          'degreeProgram' => {
            key: "us_school_#{ITERATOR}_college"
          },
          'maximumContributionAmount' => {
            key: "us_school_#{ITERATOR}_maximum_contribution"
          }
        },
        'foreignSchools' => {
          limit: 4,
          'maximumNumberofStudents' => {
            key: "foreign_school_#{ITERATOR}_max_students"
          },
          'degreeLevel' => {
            key: "foreign_school_#{ITERATOR}_degree_level"
          },
          'currencyType' => {
            key: "foreign_school_#{ITERATOR}_currency_type"
          },
          'maximumContributionAmount' => {
            key: "foreign_school_#{ITERATOR}_maximum_contribution"
          }
        }
      }.freeze

      def merge_fields(_options = {})
        form_data = JSON.parse(JSON.generate(@form_data))

        convert_full_name(form_data, %w[pointOfContact fullName])
        convert_full_name(form_data, %w[pointOfContactTwo fullName])
        convert_full_name(form_data, %w[authorizedOfficial fullName])

        format_institutions(form_data)
        format_schools(form_data)
        format_agreement_type(form_data)

        form_data['authenticatedUser'] =
          form_data['isAuthenticated'] ? 'Filled out by authenticated user' : 'Filled out by unauthenticated user'

        form_data
      end

      # convenience method for altering a value arbitrarily deep in a hash
      # Hash::dig allows us to safely access deeply-nested values, but not assign them,
      # so a little extra work is needed to do so. In this case we just `dig` to one
      # level before the end and then manually make the assignment
      def convert_full_name(hash, path)
        hash.dig(*path[0..-2])[path.last] = combine_full_name(hash.dig(*path)) if hash.dig(*path).present?
      end

      def format_date_range(range)
        return '' if range.blank?

        "#{range['from']} to #{range['to']}"
      end

      def format_agreement_type(form_data)
        form_data['agreementType'] = AGREEMENT_TYPES[form_data['agreementType']] || form_data['agreementType']
      end

      def format_institutions(form_data)
        institution_arr = form_data['agreementType'] == 'withdrawFromYellowRibbonProgram' ? form_data['withdrawFromYellowRibbonProgram'] : form_data['institutionDetails']

        if institution_arr.present?
          form_data['primaryInstitution'] = institution_arr.first
          form_data['primaryInstitution']['institutionAddress'] =
            combine_full_address(form_data['primaryInstitution']['institutionAddress'])

          form_data['branchCampuses'] = institution_arr[1..].map do |d|
            d.merge({
                      'nameAndAddress' => "#{d['institutionName']}\n#{combine_full_address(d['institutionAddress'])}"
                    })
          end
        end
      end

      def format_schools(form_data)
        programs = form_data['yellowRibbonProgramAgreementRequest'] || []
        form_data['usSchools'] = programs.filter { |s| s['currencyType'] == 'USD' }
        form_data['foreignSchools'] = programs.filter { |s| s['currencyType'] != 'USD' }

        form_data['academicYear'] = format_date_range(programs.first['yearRange']) if programs.size.positive?

        form_data['numEligibleStudents'] = programs.sum { |program| program['maximumNumberofStudents'] }
      end
    end
  end
end
