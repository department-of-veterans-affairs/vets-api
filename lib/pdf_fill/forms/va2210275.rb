# frozen_string_literal: true

module PdfFill
  module Forms
    class Va2210275 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'mainInstitution' => {
          'institutionName' => {
            key: 'institutionName',
            question_text: 'NAME OF EDUCATIONAL TRAINING INSTITUTION (ETI)',
            question_num: 1
          },
          'facilityCode' => {
            key: 'facilityCode',
            question_text: 'FACILITY CODE',
            question_num: 2
          },
          'institutionAddress' => {
            question_text: 'MAILING ADDRESS OF EDUCATIONAL TRAINING INSTITUTION',
            question_num: 3,
            'mailingAddress' => {
              key: 'mailingAddress'
            }
          }
        },
        'agreementType' => {
          question_text: 'AGREEMENT_TYPE (CHECK ONE)',
          question_num: 4,
          'newCommitment' => {
            key: 'newCommitment'
          },
          'withdrawal' => {
            key: 'withdrawal'
          }
        },
        'additionalInstitutions' => {
          question_num: 5,
          question_text: 'List all participating locations',
          first_key: 'institutionName',
          limit: 6,
          'institutionName' => {
            key: "schoolName[#{ITERATOR}]"
          },
          'institutionAddress' => {
            key: "schoolLocation[#{ITERATOR}]"
          },
          'facilityCode' => {
            key: "schoolFacilityCode[#{ITERATOR}]"
          },
          'pointOfContact' => {
            key: "schoolPoc[#{ITERATOR}]"
          },
          'email' => {
            key: "schoolEmail[#{ITERATOR}]"
          }
        }
      }.freeze

      def merge_fields(_options = {})
        merge_address_helpers
        merge_agreement_type_helpers
        merge_additional_institution_helpers

        @form_data
      end

      private

      def merge_address_helpers
        address = @form_data.dig('mainInstitution', 'institutionAddress')
        format_address(address)
      end

      def format_address(address)
        address['country'] = format_country(address)
        address['state'] = format_state(address)
        address['mailingAddress'] = combine_full_address_extras(address)
      end

      # Unnecessary to include country code in mailing address if domestic
      def format_country(address)
        address['country'].in?(%w[USA US]) ? nil : extract_country(address)
      end

      # Format Mexican state names
      def format_state(address)
        return address['state'] unless address['country'].in?(%w[MEX MX])

        address['state'].gsub('-', ' ').titleize
      end

      def merge_agreement_type_helpers
        form_value = @form_data.delete('agreementType')
        @form_data['agreementType'] = {}
        %w[newCommitment withdrawal].each do |agreement_type|
          # Set checkbox to checked or unchecked
          checked_value = form_value == agreement_type ? 'Yes' : 'No'
          @form_data['agreementType'][agreement_type] = checked_value
        end
      end

      def merge_additional_institution_helpers
        @form_data['additionalInstitutions'].each do |institution|
          address = institution['institutionAddress']
          institution['institutionAddress'] = format_address(address)
          format_contact(institution)
        end
      end

      def format_contact(institution)
        contact = institution['pointOfContact']
        institution['email'] = contact['email']
        institution['pointOfContact'] = combine_full_name(contact['fullName'])
      end
    end
  end
end
