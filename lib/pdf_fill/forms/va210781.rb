# frozen_string_literal: true

module PdfFill
  module Forms
    class Va210781 < FormBase
      include FormHelper

      KEY = {
        'veteranFullName' => {
          'first' => {
            key: 'form1[0].#subform[0].ClaimantsFirstName[0]',
            limit: 12,
            question_num: 1,
            question_suffix: 'A',
            question_text: "VETERAN/BENEFICIARY'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'form1[0].#subform[0].ClaimantsMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[0].ClaimantsLastName[0]',
            limit: 18,
            question_num: 1,
            question_suffix: 'B',
            question_text: "VETERAN/BENEFICIARY'S LAST NAME"
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[0].ClaimantsSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[0].ClaimantsSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[0].ClaimantsSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'veteranSocialSecurityNumber1' => {
          'first' => {
            key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'veteranSocialSecurityNumber2' => {
          'first' => {
            key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_FirstThreeNumbers[1]'
          },
          'second' => {
            key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_SecondTwoNumbers[1]'
          },
          'third' => {
            key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_LastFourNumbers[1]'
          }
        },
        'vaFileNumber' => {
          key: 'form1[0].#subform[0].VAFileNumber[0]'
        },
        'veteranDateOfBirth' => {
          'month' => {
            key: 'form1[0].#subform[0].DOBmonth[0]'
          },
          'day' => {
            key: 'form1[0].#subform[0].DOBday[0]'
          },
          'year' => {
            key: 'form1[0].#subform[0].DOByear[0]'
          }
        },
        'veteranServiceNumber' => {
          key: 'form1[0].#subform[0].VeteransServiceNumber[0]'
        },
        'email' => {
          key: 'form1[0].#subform[0].PreferredEmail[0]'
        },
        'veteranPhone' => {
          key: 'form1[0].#subform[0].PreferredEmail[1]'
        },
        'veteranSecondaryPhone' => {
          key: 'form1[0].#subform[0].PreferredEmail[2]'
        },
        'signature' => {
          key: 'form1[0].#subform[2].Signature[0]'
        },
        'signatureDate' => {
          key: 'form1[0].#subform[2].Date11[0]'
        }
      }.freeze

      def merge_fields
        expand_veteran_full_name
        expand_ssn
        expand_veteran_dob

        expand_signature(@form_data['veteranFullName'])
        @form_data['signature'] = '/es/ ' + @form_data['signature']

        @form_data
      end

      private

      def expand_veteran_full_name
        @form_data['veteranFullName'] = extract_middle_i(@form_data, 'veteranFullName')
      end

      def expand_ssn
        ssn = @form_data['veteranSocialSecurityNumber']
        return if ssn.blank?
        ['', '1', '2'].each do |suffix|
          @form_data["veteranSocialSecurityNumber#{suffix}"] = split_ssn(ssn)
        end
      end

      def expand_veteran_dob
        veteran_date_of_birth = @form_data['veteranDateOfBirth']
        return if veteran_date_of_birth.blank?
        @form_data['veteranDateOfBirth'] = split_date(veteran_date_of_birth)
      end
    end
  end
end
