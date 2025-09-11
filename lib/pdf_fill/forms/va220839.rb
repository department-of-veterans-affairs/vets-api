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
        'agreementType' => {
          key: 'agreement_type',
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
        }
      }.freeze

      def merge_fields(_options = {})
        form_data = JSON.parse(JSON.generate(@form_data))

        convert_full_name(form_data, ['pointOfContact','fullName'])
        convert_full_name(form_data, ['pointOfContactTwo','fullName'])
        convert_full_name(form_data, ['authorizedOfficial','fullName'])
        form_data['primaryInstitution'] = form_data['institutionDetails'].first
        form_data['primaryInstitution']['institutionAddress'] = combine_full_address(form_data['primaryInstitution']['institutionAddress'] )

        form_data['usSchools'] = form_data['yellowRibbonProgramAgreementRequest']

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
    end
  end
end
