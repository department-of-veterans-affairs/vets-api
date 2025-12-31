# frozen_string_literal: true

module PdfFill
  module Forms
    class Va2210272 < FormBase
      include FormHelper

      KEY = {
        'applicantName' => {
          key: 'applicantName',
          question_text: 'APPLICANT\'S NAME (First, Middle Initial, Last Name)',
          question_num: 1
        },
        'mailingAddress' => {
          key: 'mailingAddress',
          question_text: 'MAILING ADDRESS (Complete Street Address, City, State and 9-Digit ZIP Code)',
          question_num: 2
        }
      }.freeze

      def merge_fields(_options = {})
        merge_identification_helpers
      end

      private

      def merge_identification_helpers
        format_applicant_name(@form_data['applicantName'])
        format_mailing_address(@form_data['mailingAddress'])
      end

      def format_applicant_name(full_name)
        # Convert middle name to middle initial if present
        full_name['middle']&.slice!(1..)
        @form_data['applicantName'] = combine_full_name(full_name)
      end
    end
  end
end
