# frozen_string_literal: true

module PdfFill
  module Forms
    class Va220810 < FormBase
      KEY = {
        'applicantName' => {
          key: 'applicantName',
          question_text: 'APPLICANT\'S NAME (First, Middle Initial, Last Name)',
          question_num: 1
        },
        'mailingAddress' => {
          key: 'mailingAddress',
          question_text: 'APPLICANT\'S ADDRESS (Number and street or rural route, P.O. Box, City, State, Zip Code)',
          question_num: 2,
          question_suffix: 'A'
        },
        'emailAddress' => {
          key: 'emailAddress',
          question_text: 'APPLICANT\'S EMAIL ADDRESS',
          question_num: 2,
          question_suffix: 'B'
        }
      }

      def merge_fields(_options = {})
        merge_identification_helpers

        @form_data
      end

      private

      def merge_identification_helpers
        format_applicant_name(@form_data['applicantName'])
      end

      def format_applicant_name(name)
        # Convert middle name to middle initial if present
        name['middle'] = "#{name['middle'][0]}." if name['middle']
        @form_data['applicantName'] = combine_full_name(name)
      end
    end
  end
end
