# frozen_string_literal: true

require 'date'
require 'debts_api/v0/fsr_form_transform/expense_calculator'
require 'debts_api/v0/fsr_form_transform/utils'

module DebtsApi
  module V0
    module FsrFormTransform
      class AdditionalDataCalculator
        include ::FsrFormTransform::Utils

        def initialize(form)
          @form = form
          @comments = @form.dig('additional_data', 'additional_comments')
          @expense_calculator = DebtsApi::V0::FsrFormTransform::ExpenseCalculator.build(@form)
          @bankruptcy = @form.dig('additional_data', 'bankruptcy') || {}
        end

        def get_data
          data = { 'bankruptcy' => get_bankruptcy_data }
          data['additionalComments'] = get_comments unless get_comments == "\n"
          data
        end

        def get_bankruptcy_data
          return {} if @bankruptcy.blank?

          {
            'hasBeenAdjudicatedBankrupt' => @form['questions']['has_been_adjudicated_bankrupt'],
            'dateDischarged' => get_discharged_date,
            'courtLocation' => @bankruptcy['court_location'],
            'docketNumber' => @bankruptcy['docket_number']
          }
        end

        private

        def get_comments
          "#{@comments}\n#{joined_filtered_expenses}"
        end

        def joined_filtered_expenses
          filtered_expenses = @expense_calculator.filtered_expenses

          return '' if filtered_expenses.blank?

          joined_expenses = filtered_expenses.map do |expense|
            cash_str = dollars_cents(expense['amount'].to_f).gsub(/(\d)(?=(\d{3})+.\d{2}$)/, '\1,')
            "#{expense['name']} ($#{cash_str})"
          end.join(', ')

          "Individual expense amount: #{joined_expenses}"
        end

        def get_discharged_date
          raw_date = @bankruptcy['date_discharged']

          return '00/0000' if raw_date.blank?

          date_object = Date.parse(raw_date)

          "#{date_object.strftime('%m')}/#{date_object.year}"
        rescue Date::Error => e
          Rails.logger.error("DebtsApi AdditionalDataCalculator#get_discharge_date: #{e.message}")
          Rails.logger.info(
            "DebtsApi AdditionalDataCalculator#get_discharge_date input: #{@bankruptcy['date_discharged']}"
          )

          '00/0000'
        end
      end
    end
  end
end
