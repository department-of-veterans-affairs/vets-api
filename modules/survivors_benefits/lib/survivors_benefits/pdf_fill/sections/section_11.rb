# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

module SurvivorsBenefits
  module PdfFill
    # Section XI: Direct Deposit Information
    class Section11 < Section
      # Section configuration hash
      KEY = {
        'bankAccount' => {
          'bankName' => {
            'line_one' => {
              limit: 17,
              key: 'form1[0].#subform[217].Name_Of_Financial_Institution[0]'
            },
            'line_two' => {
              limit: 17,
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
            key: 'form1[0].#subform[217].Account_Number[0]'
          }
        }
      }.freeze

      def expand(form_data = {})
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
          'line_two' => chunks[1]
        }.compact
      end

      def account_type_to_radio(account_type)
        case account_type&.downcase
        when 'checking' then 1
        when 'savings' then 2
        else 'Off'
        end
      end

      def digits_only(value)
        value.to_s.gsub(/\D/, '')
      end
    end
  end
end
