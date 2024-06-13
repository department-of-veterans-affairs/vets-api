# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/income_calculator'
require 'debts_api/v0/fsr_form_transform/enhanced_expense_calculator'

module DebtsApi
  module V0
    module FsrFormTransform
      class InstallmentContractsOtherDebtsCalculator
        def initialize(form)
          @form = form
        end

        def get_data
          transformed_installment_contracts = @form['installment_contracts'].map do |it|
            get_installment_or_other_debt_data_for(it)
          end

          transformed_cc_payments = @form['expenses']['credit_card_bills'].map do |it|
            get_installment_or_other_debt_data_for(it)
          end

          transformed_installment_contracts + transformed_cc_payments
        end

        def get_totals_data
          {
            'originalAmount' => get_total_installment_debt_amounts_for('original_amount'),
            'unpaidBalance' => get_total_installment_debt_amounts_for('unpaid_balance'),
            'amountDueMonthly' => get_total_installment_debt_amounts_for('amount_due_monthly'),
            'amountPastDue' => get_total_installment_debt_amounts_for('amount_past_due')
          }
        end

        private

        def get_installment_or_other_debt_data_for(item)
          data = {
            'purpose' => item['purpose'],
            'creditorName' => item['creditor_name'],
            'originalAmount' => format_installment_debt_number(item['original_amount']),
            'unpaidBalance' => format_installment_debt_number(item['unpaid_balance']),
            'amountDueMonthly' => item['amount_due_monthly'],
            'amountPastDue' => format_installment_debt_number(item['amount_past_due']),
            'creditorAddress' => get_creditor_address_for(item)
          }
          data['dateStarted'] = sanitize_date_string(item['date_started']) if item['date_started'].present?

          data
        end

        def get_creditor_address_for(item)
          item['creditor_address'].presence ||
            {
              'addresslineOne' => '',
              'addresslineTwo' => '',
              'addresslineThree' => '',
              'city' => '',
              'stateOrProvince' => '',
              'zipOrPostalCode' => '',
              'countryName' => ''
            }
        end

        def get_total_installment_debt_amounts_for(key)
          credit_card_bills = @form['expenses']['credit_card_bills']
          installment_contracts = @form['installment_contracts']
          sum_amount = [*credit_card_bills, *installment_contracts].reduce(0) { |acc, it| acc + str_to_num(it[key]) }

          format('%.2f', sum_amount)
        end

        def format_installment_debt_number(number)
          if number.blank?
            ''
          # number.zero? breaks tests, so comparison operator is needed
          # rubocop:disable Style/NumericPredicate
          elsif number == 0
            # rubocop:enable Style/NumericPredicate
            '0.00'
          else
            number
          end
        end

        def str_to_num(str)
          return str if str.is_a? Numeric
          return 0 unless str.instance_of?(String)

          str.gsub(/[^0-9.-]/, '').to_i || 0
        end

        def sanitize_date_string(date)
          return '' if date.empty?

          date_string = date.gsub('XX', '01')
          date_string << '-01' if date_string.split('-').length == 2
          year, month = date_string.split('-')
          month = "0#{month}" if month.length == 1
          "#{month}/#{year}"
        end
      end
    end
  end
end
