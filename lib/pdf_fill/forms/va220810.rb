# frozen_string_literal: true

module PdfFill
  module Forms
    class Va220810 < FormBase
      include FormHelper
      include FormHelper::PhoneNumberFormatting

      KEY = {
        'applicantName' => {
          key: 'applicantName',
          question_text: 'APPLICANT\'S NAME (First, Middle Initial, Last Name)',
          question_num: 1,
          limit: 100
        },
        'mailingAddress' => {
          key: 'mailingAddress',
          question_text: 'APPLICANT\'S ADDRESS (Number and street or rural route, P.O. Box, City, State, Zip Code)',
          question_num: 2,
          question_suffix: 'A',
          limit: 120
        },
        'emailAddress' => {
          key: 'emailAddress',
          question_text: 'APPLICANT\'S EMAIL ADDRESS',
          question_num: 2,
          question_suffix: 'B',
          limit: 100
        },
        'phone' => {
          question_text: 'TELEPHONE NUMBER (Include Area Code)',
          question_num: 3,
          'mobilePhone' => {
            key: 'mobilePhone',
            question_text: 'DAYTIME',
            question_suffix: 'A',
            limit: 27
          },
          'homePhone' => {
            key: 'homePhone',
            question_text: 'EVENING',
            question_suffix: 'B',
            limit: 27
          }
        },
        'ssn' => {
          key: 'ssn',
          question_text: 'SOCIAL SECURITY NUMBER OF APPLICANT',
          question_num: 4,
          limit: 50
        },
        'vaFileNumber' => {
          key: 'vaFileNumber',
          question_text: 'VA FILE NUMBER (For chapter 35, enter the veteran\'s file number and include your suffix indicator. For Chapter 30 dependent\'s case, enter the file number of the person who transferred entitlement to you)', # rubocop:disable Layout/LineLength
          question_num: 5,
          limit: 100
        },
        'hasPreviouslyApplied' => {
          question_text: 'HAVE YOU PREVIOUSLY APPLIED FOR VA EDUCATION BENEFITS?',
          question_num: 6,
          question_suffix: 'A',
          'yes' => {
            key: 'hasPreviouslyAppliedYes',
            question_text: 'YES (If "Yes," show the specific benefit you previously applied for in Item 6B)'
          },
          'no' => {
            key: 'hasPreviouslyAppliedNo',
            question_text: 'NO (If "No," you must also complete an Application for VA Education Benefits, VA Form 22-1990)' # rubocop:disable Layout/LineLength
          }
        },
        'vaBenefitProgram' => {
          key: 'vaBenefitProgram',
          question_text: 'WHAT EDUCATION BENEFIT HAVE YOU APPLIED FOR PREVIOUSLY?',
          question_num: 6,
          question_suffix: 'B',
          limit: 100
        },
        'examName' => {
          key: 'examName',
          question_text: 'NAME OF EXAM',
          question_num: 7,
          limit: 50
        },
        'organization' => {
          key: 'organization',
          question_text: 'ORGANIZATION GIVING EXAM (Indicate if taken online)',
          question_num: 8,
          limit: 50
        },
        'examDate' => {
          key: 'examDate',
          question_text: 'DATE EXAM TAKEN (MM/DD/YYYY) (Attach a copy of exam results)',
          question_num: 9,
          limit: 50
        },
        'examCost' => {
          key: 'examCost',
          question_text: 'ITEMIZE EXAM COST INCLUDING FEES (Attach exam receipt)',
          question_num: 10,
          limit: 265
        },
        'remarks' => {
          key: 'remarks',
          question_text: 'REMARKS (Optional)',
          question_num: 11,
          limit: 635
        },
        'statementOfTruthSignature' => {
          key: 'statementOfTruthSignature',
          question_text: 'SIGNATURE OF APPLICANT (Sign in ink)',
          question_num: 12,
          limit: 78
        },
        'dateSigned' => {
          key: 'dateSigned',
          question_text: 'DATE SIGNED (MM/DD/YYYY)',
          question_num: 13,
          limit: 28
        }
      }.freeze

      def merge_fields(_options = {})
        merge_identification_helpers
        format_has_previously_applied
        format_organization
        merge_date_helpers

        @form_data
      end

      private

      def merge_identification_helpers
        format_applicant_name(@form_data['applicantName'])
        format_address(@form_data['mailingAddress'])
        format_phone
        @form_data['ssn'] = split_ssn(@form_data['ssn']).values.join('-')
        @form_data['vaFileNumber'].concat('-', @form_data['payeeNumber'])
      end

      def format_applicant_name(name)
        # Convert middle name to middle initial if present
        name['middle'] = "#{name['middle'][0]}." if name['middle']
        @form_data['applicantName'] = combine_full_name(name)
      end

      def format_address(address)
        @country = address['country']
        normalize_mailing_address(address)
        @form_data['mailingAddress'] = combine_full_address_extras(address)
      end

      def format_phone
        @form_data['phone'] = @form_data.slice('homePhone', 'mobilePhone')
        @form_data['phone'].transform_values!(&method(:format_us_phone)) if domestic?(@country)
      end

      def format_has_previously_applied
        flag = @form_data['hasPreviouslyApplied']
        @form_data['hasPreviouslyApplied'] = {
          'yes' => flag ? 'Yes' : 'Off',
          'no' => flag ? 'Off' : 'Yes'
        }
      end

      def format_organization
        normalize_mailing_address(@form_data['organizationAddress'])
        @form_data['organization'] = combine_name_addr_extras(@form_data,
                                                              'organizationName',
                                                              'organizationAddress')
      end

      def merge_date_helpers
        %w[examDate dateSigned].each(&method(:format_date))
      end

      def format_date(key)
        str = @form_data[key]
        @form_data[key] = str.to_date.strftime(self.class.date_strftime)
      end
    end
  end
end
