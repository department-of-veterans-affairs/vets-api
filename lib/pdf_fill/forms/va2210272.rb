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
          question_num: 1,
          limit: 54
        },
        'address' => {
          question_num: 2,
          'mailing' => {
            key: 'mailingAddress',
            question_text: 'MAILING ADDRESS (Complete Street Address, City, State and 9-Digit ZIP Code)',
            question_suffix: 'A',
            limit: 340
          },
          'email' => {
            key: 'emailAddress',
            question_text: 'APPLICANT\'S EMAIL ADDRESS',
            question_suffix: 'B',
            limit: 65
          }
        },
        'phone' => {
          question_text: 'TELEPHONE NUMBER (Include Area Code)',
          question_num: 3,
          'homePhone' => {
            key: 'homePhone',
            question_text: 'HOME',
            question_num: 3,
            question_suffix: 'A',
            limit: 32
          },
          'mobilePhone' => {
            key: 'mobilePhone',
            question_text: 'MOBILE',
            question_num: 3,
            question_suffix: 'B',
            limit: 46
          }
        },
        'vaFileNumber' => {
          key: 'vaFileNumber',
          question_text: 'VA FILE NUMBER',
          question_num: 4,
          limit: 42
        },
        'payeeNumber' => {
          key: 'payeeNumber',
          question_text: 'PAYEE NUMBER (if applicable)',
          question_num: 5,
          limit: 42
        },
        'hasPreviouslyApplied' => {
          question_text: 'HAVE YOU PREVIOUSLY APPLIED',
          question_num: 6,
          question_suffix: 'A',
          'hasPreviouslyAppliedYes' => {
            key: 'hasPreviouslyAppliedYes',
            question_text: 'YES'
          },
          'hasPreviouslyAppliedNo' => {
            key: 'hasPreviouslyAppliedNo',
            question_text: 'NO'
          }
        },
        'vaBenefitProgram' => {
          key: 'vaBenefitProgram',
          question_text: 'WHAT EDUCATION BENEFIT(S) HAVE YOU APPLIED FOR PREVIOUSLY?',
          question_num: 6,
          question_suffix: 'B',
          limit: 87
        },
        'testName' => {
          key: 'testName',
          question_text: 'NAME OF TEST',
          question_num: 7,
          limit: 87
        },
        'orgNameAndAddress' => {
          key: 'orgNameAndAddress',
          question_text: 'NAME OF ORGANIZATION AWARDING LICENSE OR CERTIFICATION (Include address)',
          question_num: 8,
          limit: 340
        },
        'prepCourseName' => {
          key: 'prepCourseName',
          question_text: 'NAME OF COURSE',
          question_num: 9,
          limit: 46
        },
        'prepCourseOrgNameAndAddress' => {
          key: 'prepCourseOrgNameAndAddress',
          question_text: 'ORGANIZATION GIVING PREP COURSE (Please include address)',
          question_num: 10,
          question_suffix: 'A',
          limit: 234
        },
        'prepCourseTakenOnline' => {
          question_text: 'TAKEN ONLINE?',
          question_num: 10,
          question_suffix: 'B',
          'prepCourseTakenOnlineYes' => {
            key: 'prepCourseTakenOnlineYes',
            question_text: 'YES'
          },
          'prepCourseTakenOnlineNo' => {
            key: 'prepCourseTakenOnlineNo',
            question_text: 'NO'
          }
        },
        'prepCourseStartDate' => {
          key: 'prepCourseStartDate',
          question_text: 'COURSE START DATE (MM/DD/YYYY)',
          question_num: 11,
          question_suffix: 'A',
          limit: 24
        },
        'prepCourseEndDate' => {
          key: 'prepCourseEndDate',
          question_text: 'COURSE END DATE (MM/DD/YYYY)',
          question_num: 11,
          question_suffix: 'B',
          limit: 23
        },
        'prepCourseCost' => {
          key: 'prepCourseCost',
          question_text: 'ITEMIZE PREP COURSE COST INCLUDING FEES (Attach receipt)',
          question_num: 12,
          limit: 524
        },
        'remarks' => {
          key: 'remarks',
          question_text: 'REMARKS',
          question_num: 14,
          limit: 3200
        },
        'statementOfTruthSignature' => {
          key: 'statementOfTruthSignature',
          question_text: 'SIGNATURE OF APPLICANT',
          question_num: 15,
          limit: 65
        },
        'dateSigned' => {
          key: 'dateSigned',
          question_text: 'DATE SIGNED (MM/DD/YYYY)',
          question_num: 16,
          limit: 20
        }
      }.freeze

      def merge_fields(_options = {})
        merge_identification_helpers
        merge_education_helpers
        merge_licensing_helpers
        merge_prep_course_helpers
        merge_date_helpers

        @form_data
      end

      private

      def merge_identification_helpers
        format_applicant_name(@form_data['applicantName'])
        format_address(@form_data['mailingAddress'].dup)
        format_phone
      end

      def format_applicant_name(name)
        # Convert middle name to middle initial if present
        name['middle'] = "#{name['middle'][0]}." if name['middle']
        @form_data['applicantName'] = combine_full_name(name)
      end

      def format_address(mailing_address)
        normalize_mailing_address(mailing_address)
        @form_data['address'] = {
          'mailing' => combine_full_address_extras(mailing_address),
          'email' => @form_data['emailAddress']
        }
      end

      def format_phone
        @form_data['phone'] = @form_data.slice('homePhone', 'mobilePhone')
        country = @form_data['mailingAddress']['country']
        @form_data['phone'].transform_values!(&method(:format_us_phone)) if domestic?(country)
      end

      def merge_education_helpers
        format_yes_no_checkbox('hasPreviouslyApplied')
      end

      def merge_licensing_helpers
        normalize_mailing_address(@form_data['organizationAddress'])
        @form_data['orgNameAndAddress'] = combine_name_addr_extras(@form_data,
                                                                   'organizationName',
                                                                   'organizationAddress')
      end

      def merge_prep_course_helpers
        normalize_mailing_address(@form_data['prepCourseOrganizationAddress'])
        @form_data['prepCourseOrgNameAndAddress'] = combine_name_addr_extras(@form_data,
                                                                             'prepCourseOrganizationName',
                                                                             'prepCourseOrganizationAddress')
        format_yes_no_checkbox('prepCourseTakenOnline')
      end

      def format_yes_no_checkbox(boolean_key)
        flag = @form_data[boolean_key]
        @form_data[boolean_key] = {
          "#{boolean_key}Yes" => flag ? 'Yes' : 'Off',
          "#{boolean_key}No" => flag ? 'Off' : 'Yes'
        }
      end

      def merge_date_helpers
        %w[prepCourseStartDate prepCourseEndDate dateSigned].each(&method(:format_date))
      end

      def format_date(key)
        str = @form_data[key]
        @form_data[key] = str.to_date.strftime(self.class.date_strftime)
      end
    end
  end
end
