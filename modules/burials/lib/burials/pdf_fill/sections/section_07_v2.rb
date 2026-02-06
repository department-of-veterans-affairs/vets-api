# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section VII: Direct Deposit Information
    class Section7V2 < Section
      # Section configuration hash
      KEY = {
        # 31A - CURRENTLY NOT IN USE (OPTIONAL) DESIGN SKIPPED IT
        'bankName' => {
          key: 'form1[0].#subform[95].Name_Of_Financial_Institution[0]',
          limit: 25,
          question_num: 31,
          question_suffix: 'A',
          question_label: 'Name Of Financial Institution',
          question_text: 'NAME OF FINANCIAL INSTITUTION'
        },
        # 31B
        'bankAccountType' => {
          key: 'form1[0].#subform[95].RadioButtonList[12]'
        },
        # 31C
        'bankRoutingNumber' => {
          key: 'form1[0].#subform[95].Routing_Or_Transit_Number[0]'
        },
        # 31D
        'bankAccountNumber' => {
          key: 'form1[0].#subform[95].Routing_Or_Transit_Number[1]'
        }
      }.freeze

      ##
      # Expands the form data for Section 7.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        expand_bank_account(form_data)
      end

      ##
      # Expands bank account information from nested structure
      #
      # @param form_data [Hash]
      #
      # @return [void]
      def expand_bank_account(form_data)
        bank_account = form_data['bankAccount']
        return if bank_account.blank?

        # Extract account type and convert to radiobutton value
        account_type = bank_account['accountType']
        form_data['bankAccountType'] = Constants::BANK_ACCOUNT_TYPES[account_type] if account_type.present?

        # Extract routing number
        form_data['bankRoutingNumber'] = bank_account['routingNumber'] if bank_account['routingNumber'].present?

        # Extract account number
        form_data['bankAccountNumber'] = bank_account['accountNumber'] if bank_account['accountNumber'].present?

        # Remove the nested structure
        form_data.delete('bankAccount')
      end
    end
  end
end
