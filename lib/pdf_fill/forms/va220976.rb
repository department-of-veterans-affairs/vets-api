# frozen_string_literal: true

module PdfFill
  module Forms
    class Va220976 < FormBase
      include FormHelper

      INSTITUTION_TYPE_ENUM = {
        "public" => 'PUBLIC',
        "privateForProfit" => 'PRIVATE-FOR-PROFIT',
        "privateNotForProfit" => 'PRIVATE-NOT-FOR-PROFIT'
      }

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'primaryInstitution' => {
          'institutionName' => {
            key: 'institution_name'
          },
          'vaFacilityCode' => {
            key: 'institution_facility_code'
          },
          'physicalAddress' => {
            key: 'institution_physical_address'
          },
          'mailingAddress' => {
            key: 'institution_mailing_address'
          },
          'country' => {
            key: 'institution_country'
          },
          'website' => {
            key: 'institution_website'
          },
        },
        'generalInfo' => {
          'typeInitial' => {
            key: 'submission_type_initial'
          },
          'typeApproval' => {
            key: 'submission_type_approval'
          },
          'typeReapproval' => {
            key: 'submission_type_reapproval'
          },
          'typeUpdate' => {
            key: 'submission_type_update'
          },
          'typeOther' => {
            key: 'submission_type_other'
          },
          'otherExplanation' => {
            key: 'other_explanation'
          },
          'updateExplanation' => {
            key: 'update_explanation'
          },
          'institutionType' => {
            key: 'institution_type'
          },
          'isHigherLearning' => {
            key: 'is_higher_learning'
          },
          'isTitle4' => {
            key: 'is_title_4'
          },
          'higherLearningDescription' => {
            key: 'is_higher_learning_description'
          },
          'title4Description' => {
            key: 'is_title_4_description'
          }
        }
      }.freeze

      def merge_fields(_options = {})
        form_data = JSON.parse(JSON.generate(@form_data))

        format_general_info(form_data)
        format_institutions(form_data)
        form_data
      end

      def format_institutions(form_data)
        form_data['primaryInstitution'] = form_data['institutionDetails'].first
        form_data['primaryInstitution']['physicalAddress'] = combine_full_address(form_data['primaryInstitution']['physicalAddress'])
        form_data['primaryInstitution']['mailingAddress'] = combine_full_address(form_data['primaryInstitution']['mailingAddress'])
        form_data['primaryInstitution']['country'] = form_data['primaryInstitution']['isForeignCountry'] ? form_data['primaryInstitution']['physicalAddress']['country'] : ''
        form_data['primaryInstitution']['website'] = form_data['website']

        form_data['branches'] = form_data['institutionDetails'][1..].map do |data|
          {
            'name' => data['institutionName'],
            'address' => combine_full_address(data['physicalAddress'])
          }
        end
      end

      def format_general_info(form_data)
        form_data['generalInfo'] = {
          'typeInitial' => form_data['submissionReasons']['initialApplication'] ? 'Yes' : 'Off',
          'typeApproval' => form_data['submissionReasons']['approvalOfNewPrograms'] ? 'Yes' : 'Off',
          'typeReapproval' => form_data['submissionReasons']['reapproval'] ? 'Yes' : 'Off',
          'typeUpdate' => form_data['submissionReasons']['updateInformation'] ? 'Yes' : 'Off',
          'typeOther' => form_data['submissionReasons']['other'] ? 'Yes' : 'Off',
          'updateExplanation' => form_data['submissionReasons']['updateInformationText'],
          'otherExplanation' => form_data['submissionReasons']['otherText'],
          'institutionType' => INSTITUTION_TYPE_ENUM[form_data['institutionClassification']],
          'isHigherLearning' => form_data['institutionProfile']['isIHL'] ? 'YES' : 'NO',
          'isTitle4' => form_data['institutionProfile']['participatesInTitleIV'] ? 'YES' : 'NO',
          'higherLearningDescription' => form_data['institutionProfile']['ihlDegreeTypes'],
          'title4Description' => form_data['institutionProfile']['opeidNumber']
        }
      end
    end
  end
end
