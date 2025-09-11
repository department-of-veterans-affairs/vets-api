# frozen_string_literal: true

module PdfFill
  module Forms
    class Va220839 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

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
          },
        },
        'branchCampuses' => {
          limit: 4,
          'nameAndAddress' => {
            key: "branch_campus[#{ITERATOR}][name]",
          },
          'facilityCode' => {
            key: "branch_campus[#{ITERATOR}][facility_code]",
          },
        },
        'agreementType' => {
          key: 'agreement_type',
        },
        'numEligibleStudents' => {
          key: 'num_eligible_students',
        },
        'academicYear' => {
          key: 'academic_year',
        },
        'yellowRibbonProgramTerms' => {
          'firstAcknowledgement' => {
            key: 'terms_initials_1',
          },
          'secondAcknowledgement' => {
            key: 'terms_initials_2',
          },
          'thirdAcknowledgement' => {
            key: 'terms_initials_3',
          },
          'fourthAcknowledgement' => {
            key: 'terms_initials_4',
          },
        },
        'pointOfContact' => {
          'fullName' => {
            key: 'poc_name',
          },
          'phoneNumber' =>  {
            key: 'poc_phone',
          },
          'emailAddress' =>  {
            key: 'poc_email',
          }
        },
        'pointOfContactTwo' => {
          'fullName' => {
            key: 'sco_name',
          },
          'phoneNumber' =>  {
            key: 'sco_phone',
          },
          'emailAddress' =>  {
            key: 'sco_email',
          }
        },
        'authorizedOfficial' => {
          'fullName' => {
            key: 'ao_name',
          },
          'title' => {
            key: 'ao_title',
          },
          'phoneNumber' => {
            key: 'ao_phone',
          },
        },
        'statementOfTruthSignature' => {
          key: 'ao_signature'
        },
        'dateSigned' => {
          key: 'date_signed'
        },
        'usSchools' => {
          limit: 11,
          'maximumNumberofStudents' => {
            key: "us_school[#{ITERATOR}][max_students]",
          },
          'degreeLevel' => {
            key: "us_school[#{ITERATOR}][degree_level]",
          },
          'degreeProgram' => {
            key: "us_school[#{ITERATOR}][college]",
          },
          'maximumContributionAmount' => {
            key: "us_school[#{ITERATOR}][maximum_contribution]",
          },
        },
        'foreignSchools' => {
          limit: 4,
          'maximumNumberofStudents' => {
            key: "foreign_school[#{ITERATOR}][max_students]",
          },
          'degreeLevel' => {
            key: "foreign_school[#{ITERATOR}][degree_level]",
          },
          'currencyType' => {
            key: "foreign_school[#{ITERATOR}][currency_type]",
          },
          'maximumContributionAmount' => {
            key: "foreign_school[#{ITERATOR}][maximum_contribution]",
          },
        }
      }.freeze

      def merge_fields(_options = {})
        form_data = JSON.parse(JSON.generate(@form_data))

        convert_full_name(form_data, ['pointOfContact','fullName'])
        convert_full_name(form_data, ['pointOfContactTwo','fullName'])
        convert_full_name(form_data, ['authorizedOfficial','fullName'])

        form_data['agreementType'] = case form_data['agreementType']
        when 'startNewOpenEndedAgreement' then 'New open-ended agreement'
        when 'modifyExistingAgreement' then 'Modification to existing agreement'
        when 'withdrawFromYellowRibbonProgram' then 'Withdrawl of Yellow Ribbon agreement'
        end

        if form_data['institutionDetails'].present?
          form_data['primaryInstitution'] = form_data['institutionDetails'].first
          form_data['primaryInstitution']['institutionAddress'] = combine_full_address(form_data['primaryInstitution']['institutionAddress'] )

          form_data['branchCampuses'] = form_data['institutionDetails'][1..].map do |d|
            d.merge({
              'nameAndAddress' => "#{d['institutionName']}\n#{combine_full_address(d['institutionAddress'])}"
            })
          end
        end

        programs = form_data['yellowRibbonProgramAgreementRequest'] || []
        form_data['usSchools'] = programs.filter{ |s| s['currencyType'] == 'USD' }
        form_data['foreignSchools'] = programs.filter{ |s| s['currencyType'] != 'USD' }

        if programs.size.positive?
          form_data['academicYear'] = format_date_range(programs.first['yearRange'])
        end

        form_data['numEligibleStudents'] = programs.sum{|program| program['eligibleIndividuals']}

        form_data
      end

      # convenience method for altering a value arbitrarily deep in a hash
      # Hash::dig allows us to safely access deeply-nested values, but not assign them,
      # so a little extra work is needed to do so. In this case we just `dig` to one
      # level before the end and then manually make the assignment
      def convert_full_name(hash, path)
        if hash.dig(*path).present?
          hash.dig(*path[0..-2])[path.last] = combine_full_name(hash.dig(*path))
        end
      end

      def format_date_range(range)
        return '' unless range.present?

        "#{range['from']} to #{range['to']}"
      end
    end
  end
end
