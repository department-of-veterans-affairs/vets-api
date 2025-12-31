# frozen_string_literal: true

module PdfFill
  module Forms
    class Va2210272 < FormBase
      include FormHelper
      include FormHelper::PhoneNumberFormatting

      KEY = {
        'applicantName' => {
          key: 'applicantName',
          question_text: 'APPLICANT\'S NAME (First, Middle Initial, Last Name)',
          question_num: 1
        },
        'address' => {
          question_num: 2,
          'mailing' => {
            key: 'mailingAddress',
            question_text: 'MAILING ADDRESS (Complete Street Address, City, State and 9-Digit ZIP Code)',
            question_suffix: 'A'
          },
          'email' => {
            key: 'emailAddress',
            question_text: 'APPLICANT\'S EMAIL ADDRESS',
            question_suffix: 'B'
          }
        },
        'phone' => {
          question_text: 'TELEPHONE NUMBER (Include Area Code)',
          question_num: 3,
          'homePhone' => {
            key: 'homePhone',
            question_text: 'HOME',
            question_num: 3,
            question_suffix: 'A'
          },
          'mobilePhone' => {
            key: 'mobilePhone',
            question_text: 'MOBILE',
            question_num: 3,
            question_suffix: 'B'
          }
        },
        'vaFileNumber' => {
          key: 'vaFileNumber',
          question_text: 'VA FILE NUMBER',
          question_num: 4
        },
        'payeeNumber' => {
          key: 'payeeNumber',
          question_text: 'PAYEE NUMBER (if applicable)',
          question_num: 5
        }
      }.freeze

      def merge_fields(_options = {})
        merge_identification_helpers
      end

      private

      def merge_identification_helpers
        format_applicant_name(@form_data['applicantName'])
        format_address
        format_phone
      end

      def format_applicant_name(full_name)
        # Convert middle name to middle initial if present
        full_name['middle']&.slice!(1..)
        @form_data['applicantName'] = combine_full_name(full_name)
      end

      def format_address
        mailing = @form_data['mailingAddress'].dup
        normalize_mailing_address(mailing)
        @form_data['address'] = {
          'mailing' => combine_full_address_extras(mailing),
          'email' => @form_data['emailAddress']
        }
      end

      def format_phone
        @form_data['phone'] = @form_data.slice('homePhone', 'mobilePhone')
        country = @form_data['mailingAddress']['country']
        @form_data['phone'].transform_values!(&method(:format_us_phone)) if domestic?(country)
      end
    end
  end
end
