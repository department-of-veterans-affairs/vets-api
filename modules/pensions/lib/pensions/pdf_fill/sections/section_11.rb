# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section XI: Direct Deposit Information
    class Section11 < Section
      # Section configuration hash
      KEY = {
        'bankAccount' => {
          # 11a
          'bankName' => {
            limit: 30,
            question_num: 11,
            question_suffix: 'A',
            question_label: 'Name of Financial Institution',
            question_text: 'NAME OF FINANCIAL INSTITUTION',
            key: 'form1[0].#subform[54].Name_Of_Financial_Institution[0]'
          },
          # 11b
          'accountType' => {
            key: 'form1[0].#subform[54].RadioButtonList[55]'
          },
          # 11c
          'routingNumber' => {
            limit: 9,
            question_num: 11,
            question_suffix: 'C',
            question_label: 'Routing Number',
            question_text: 'ROUTING NUMBER',
            key: 'form1[0].#subform[54].Routing_Number[0]'
          },
          # 11d
          'accountNumber' => {
            limit: 15,
            question_num: 11,
            question_suffix: 'D',
            question_label: 'Account Number',
            question_text: 'ACCOUNT NUMBER',
            key: 'form1[0].#subform[54].Account_Number[0]'
          }
        }
      }.freeze

      ##
      # Processes bank account information, converting account type to expected PDF values.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        account_type = form_data.dig('bankAccount', 'accountType')

        form_data['bankAccount'] = form_data['bankAccount'].to_h.merge(
          'accountType' => case account_type
                           when 'checking' then 0
                           when 'savings' then 1
                           else 2 if form_data['bankAccount'].nil?
                           end
        )
      end
    end
  end
end
