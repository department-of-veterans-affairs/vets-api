# frozen_string_literal: true

require 'medical_expense_reports/pdf_fill/section'

module MedicalExpenseReports
  module PdfFill
    # Addendum B: Other Medical Expenses
    class AddendumB < Section
      # Section configuration hash
      KEY = {
        'additionalMedicalExpenses' => {
          limit: 7,
          first_key: 'recipient',
          'recipient' => {
            iterator_offset: ->(iterator) { iterator * 2 + 26 },
            key: "form1[0].#subform[13].RadioButtonList[#{ITERATOR}]"
          },
          'recipientName' => {
            iterator_offset: ->(iterator) { iterator + 19 },
            key: "form1[0].#subform[13].Name_Of_Child_Or_Other[#{ITERATOR}]"
          },
          'paymentDate' => {
            'month' => {
              iterator_offset: ->(iterator) { iterator + 7 },
              key: "form1[0].#subform[13].Date_Costs_Paid_Month[#{ITERATOR}]"
            },
            'day' => {
              iterator_offset: ->(iterator) { iterator + 7 },
              key: "form1[0].#subform[13].Date_Costs_Paid_Day[#{ITERATOR}]"
            },
            'year' => {
              iterator_offset: ->(iterator) { iterator + 7 },
              key: "form1[0].#subform[13].Date_Costs_Paid_Year[#{ITERATOR}]"
            }
          },
          'paymentFrequency' => {
            iterator_offset: ->(iterator) { iterator * 2 + 27 },
            key: "form1[0].#subform[13].RadioButtonList[#{ITERATOR}]"
          },
          'paymentAmount' => {
            'thousands' => {
              iterator_offset: ->(iterator) { iterator + 21 },
              key: "form1[0].#subform[13].Payment_Amount[#{ITERATOR}]"
            },
            'dollars' => {
              iterator_offset: ->(iterator) { iterator * 2 + 24 },
              key: "form1[0].#subform[13].Amount[#{ITERATOR}]"
            },
            'cents' => {
              iterator_offset: ->(iterator) { iterator * 2 + 25 },
              key: "form1[0].#subform[13].Amount[#{ITERATOR}]"
            },
          },
          'provider' => {
            iterator_offset: ->(iterator) { (iterator + 1) % 7 }, # very wonky iterators!
            key: "form1[0].#subform[13].Name_Of_Provider_Insurance_Company_ETC[#{ITERATOR}]"
          },
          'purpose' => {
            iterator_offset: ->(iterator) { (iterator + 1) % 7 },
            key: "form1[0].#subform[13].Purpose_Insurance_Premium_Medical_Supplies_ETC[#{ITERATOR}]"
          }
        }
      }.freeze

      def expand(form_data = {})
        form_data['additionalMedicalExpenses'] ||= []
        form_data['additionalMedicalExpenses'] = form_data['medicalExpenses'].drop(7).map { |r| expand_expense(r) }
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
