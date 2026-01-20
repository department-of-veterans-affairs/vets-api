# frozen_string_literal: true

require 'medical_expense_reports/pdf_fill/section'

require_relative '../../constants'

module MedicalExpenseReports
  module PdfFill
    # Section V: Other Medical Expenses
    class Section5 < Section
      # Section configuration hash
      KEY = {
        'primaryMedicalExpenses' => {
          limit: 7,
          first_key: 'recipient',
          'recipient' => {
            iterator_offset: ->(iterator) { iterator + 2 },
            key: "form1[0].#subform[10].RadioButtonList[#{ITERATOR}]"
          },
          'recipientName' => {
            iterator_offset: ->(iterator) { iterator + 2 },
            key: "form1[0].#subform[10].Name_Of_Child_Or_Other[#{ITERATOR}]"
          },
          'paymentDate' => {
            'month' => {
              key: "form1[0].#subform[10].Date_Costs_Paid_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "form1[0].#subform[10].Date_Costs_Paid_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "form1[0].#subform[10].Date_Costs_Paid_Year[#{ITERATOR}]"
            }
          },
          'paymentFrequency' => {
            iterator_offset: ->(iterator) { iterator + 9 },
            key: "form1[0].#subform[10].RadioButtonList[#{ITERATOR}]"
          },
          'paymentAmount' => {
            'thousands' => {
              iterator_offset: ->(iterator) { (iterator * 3) + 1 },
              key: "form1[0].#subform[10].Payment_Amount[#{ITERATOR}]"
            },
            'dollars' => {
              iterator_offset: ->(iterator) { iterator * 3 },
              key: "form1[0].#subform[10].Payment_Amount[#{ITERATOR}]"
            },
            'cents' => {
              iterator_offset: ->(iterator) { (iterator * 3) + 2 },
              key: "form1[0].#subform[10].Payment_Amount[#{ITERATOR}]"
            }
          },
          'provider' => {
            key: "form1[0].#subform[10].Paid_To_Name_Of_Provider_Insurance_Company_ETC[#{ITERATOR}]"
          },
          'purpose' => {
            iterator_offset: ->(iterator) { [5, 4, 3, 0, 1, 6, 2][iterator] }, # fields are not ordered
            key: "form1[0].#subform[10].PURPOSE_Insurance_Premium_Medical_Supplies_ETC[#{ITERATOR}]"
          }
        }
      }.freeze

      # expand medical expenses
      def expand(form_data = {})
        form_data['medicalExpenses'] ||= []
        form_data['primaryMedicalExpenses'] =
          form_data['medicalExpenses'].take(7).map { |r| expand_expense(r) } # the rest go on Addendum B
        form_data
      end

      # expand expense payment
      def expand_expense(expense)
        expense['recipient'] = Constants::RECIPIENTS[expense['recipient']] || 'Off'
        expense['paymentDate'] = split_date(expense['paymentDate'])
        expense['paymentFrequency'] = Constants::PAYMENT_FREQUENCY[expense['paymentFrequency']] || 'Off'
        expense['paymentAmount'] = split_currency_amount_sm(expense['paymentAmount'], { 'thousands' => 3 })
        expense
      end
    end
  end
end
