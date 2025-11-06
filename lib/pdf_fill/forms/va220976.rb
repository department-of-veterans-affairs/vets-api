# frozen_string_literal: true

module PdfFill
  module Forms
    class Va220976 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'primaryInstitution' => {
          'institutionName' => {
            key: 'institution_name'
          },
          'physicalAddress' => {
            key: 'institution_physical_address'
          },
          'mailingAddress' => {
            key: 'institution_mailing_address'
          },
        },
      }.freeze

      def merge_fields(_options = {})
        form_data = JSON.parse(JSON.generate(@form_data))

        format_institutions(form_data)
        form_data
      end

      def format_institutions(form_data)
        form_data['primaryInstitution'] = form_data['institutionDetails'].first
        form_data['primaryInstitution']['physicalAddress'] = combine_full_address(form_data['primaryInstitution']['physicalAddress'])
        form_data['primaryInstitution']['mailingAddress'] = combine_full_address(form_data['primaryInstitution']['mailingAddress'])
        form_data['primaryInstitution']['country'] = form_data['primaryInstitution']['isForeignCountry'] ? form_data['primaryInstitution']['physicalAddress']['country'] : ''

        form_data['branches'] = form_data['institutionDetails'][1..].map do |data|
          {
            'name' => data['institutionName'],
            'address' => combine_full_address(data['physicalAddress'])
          }
        end
      end
    end
  end
end
