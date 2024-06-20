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
        end

        def get_data
          {
            'bankruptcy' => get_bankruptcy_data,
            'additionalComments' => get_comments
          }
        end

        def get_bankruptcy_data
          # these should probably be digs
          {
            'hasBeenAdjudicatedBankrupt' => @form['questions']['has_been_adjudicated_bankrupt'],
            'dateDischarged' => get_discharged_date,
            'courtLocation' => @form['additional_data']['bankruptcy']['court_location'],
            'docketNumber' => @form['additional_data']['bankruptcy']['docket_number']
          }
        end

        private

        def get_comments
          "#{@comments}\n#{joined_filtered_expenses}"
        end

        def joined_filtered_expenses
          filtered_expenses = @expense_calculator.filtered_expenses        
          
          if filtered_expenses.present?
            joined_expenses = filtered_expenses.map{|expense| 
              "#{expense['name']} ($#{dollars_cents(expense['amount'].to_f)})"
            }.join(', ')
            output = "Individual expense amount: #{joined_expenses}"
          else
            output = ''
          end
          output
        end

        def get_discharged_date
          # should probably be a dig
          raw_date = @form['additional_data']['bankruptcy']['date_discharged']
          date_object = Date.parse(raw_date)

          "#{date_object.strftime('%m')}/#{date_object.year}"
        end
      end
    end
  end
end
