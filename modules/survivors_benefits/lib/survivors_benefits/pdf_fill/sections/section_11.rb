# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

module SurvivorsBenefits
  module PdfFill
    # Section XI: Direct Deposit Information
    class Section11 < Section
      # Section configuration hash
      KEY = {
        'p17HeaderVeteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[217].VeteransSocialSecurityNumber_FirstThreeNumbers[7]'
          },
          'second' => {
            key: 'form1[0].#subform[217].VeteransSocialSecurityNumber_SecondTwoNumbers[7]'
          },
          'third' => {
            key: 'form1[0].#subform[217].VeteransSocialSecurityNumber_LastFourNumbers[7]'
          }
        },
        'bankAccount' => {
          'bankName' => {
            'line_one' => {
              limit: 17,
              question_num: 11,
              question_suffix: 'A',
              question_label: 'Name of Financial Institution - Line 1',
              question_text: 'NAME OF FINANCIAL INSTITUTION - LINE 1',
              key: 'form1[0].#subform[217].Name_Of_Financial_Institution[0]'
            },
            'line_two' => {
              limit: 17,
              question_num: 11,
              question_suffix: 'A',
              question_label: 'Name of Financial Institution - Line 2',
              question_text: 'NAME OF FINANCIAL INSTITUTION - LINE 2',
              key: 'form1[0].#subform[217].Name_Of_Financial_Institution[1]'
            }
          },
          'accountType' => {
            key: 'form1[0].#subform[217].RadioButtonList[64]'
          },
          'routingNumber' => {
            limit: 9,
            key: 'form1[0].#subform[217].Routing_Or_Transit_Number[0]'
          },
          'accountNumber' => {
            limit: 10,
            question_num: 11,
            question_suffix: 'C',
            question_label: 'Account Number',
            question_text: 'ACCOUNT NUMBER',
            key: 'form1[0].#subform[217].Account_Number[0]'
          }
        }
      }.freeze

      def expand(form_data = {})
        form_data['p17HeaderVeteranSocialSecurityNumber'] = split_ssn(form_data['veteranSocialSecurityNumber'])

        account = form_data['bankAccount'] || {}
        account['bankName'] = split_bank_name(account['bankName'])
        account['accountType'] = account_type_to_radio(account['accountType'])
        account['routingNumber'] = digits_only(account['routingNumber'])
        account['accountNumber'] = digits_only(account['accountNumber'])
        form_data['bankAccount'] = account
        form_data
      end

      private

      def split_bank_name(bank_name)
        return bank_name if bank_name.is_a?(Hash)
        return {} if bank_name.blank?

        chunks = bank_name.to_s.scan(/.{1,17}/)
        {
          'line_one' => chunks[0],
          'line_two' => bank_name[17..]
        }.compact
      end

      def account_type_to_radio(account_type)
        case account_type
        when 'CHECKING' then 1
        when 'SAVINGS' then 2
        when 'NO_ACCOUNT' then 4
        else 'Off'
        end
      end

      def digits_only(value)
        value.to_s.gsub(/\D/, '')
      end
    end
  end
end
