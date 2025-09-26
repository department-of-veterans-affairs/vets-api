# frozen_string_literal: true

require 'medical_expense_reports/pdf_fill/section'

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
              iterator_offset: ->(iterator) { iterator * 3 + 1 },
              key: "form1[0].#subform[10].Payment_Amount[#{ITERATOR}]"
            },
            'dollars' => {
              iterator_offset: ->(iterator) { iterator * 3 },
              key: "form1[0].#subform[10].Payment_Amount[#{ITERATOR}]"
            },
            'cents' => {
              iterator_offset: ->(iterator) { iterator * 3 + 2 },
              key: "form1[0].#subform[10].Payment_Amount[#{ITERATOR}]"
            },
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

      def expand(form_data = {})
        form_data['primaryMedicalExpenses'] ||= []
        form_data['primaryMedicalExpenses'] = form_data['medicalExpenses'].take(7).map { |r| expand_expense(r) } # the rest go on Addendum B
        form_data
      end

      def expand_expense(expense)
        expense['recipient'] = recipient_to_radio(expense['recipient'])
        expense['paymentDate'] = split_date(expense['paymentDate'])
        expense['paymentFrequency'] = frequency_to_radio(expense['paymentFrequency'])
        expense['paymentAmount'] = split_currency_amount_sm(expense['paymentAmount'], { 'thousands' => 3 })
        expense
      end

      def recipient_to_radio(recipient)
        case recipient
        when 'VETERAN' then 4
        when 'SPOUSE' then 1
        when 'CHILD' then 3
        when 'OTHER' then 2
        else 'Off'
        end
      end

      def frequency_to_radio(frequency)
        puts frequency
        case frequency
        when 'ONCE_MONTH' then 4
        when 'ONCE_YEAR' then 1
        when 'ONE_TIME' then 3
        else 'Off'
        end
      end
    end
  end
end
