# frozen_string_literal: true

require 'medical_expense_reports/pdf_fill/section'

require_relative '../../constants'

module MedicalExpenseReports
  module PdfFill
    # Addendum A: In-Home Care Or Care Facility Expenses
    class AddendumA < Section
      # Section configuration hash
      KEY = {
        'additionalCareExpenses' => {
          limit: 6,
          first_key: 'recipient',
          'recipient' => {
            iterator_offset: ->(iterator) { iterator + 20 },
            key: "form1[0].#subform[12].RadioButtonList[#{ITERATOR}]"
          },
          'recipientName' => {
            iterator_offset: ->(iterator) { iterator + 13 },
            key: "form1[0].#subform[12].Name_Of_Child_Or_Other[#{ITERATOR}]"
          },
          'provider' => {
            iterator_offset: ->(iterator) { iterator + 2 },
            key: "form1[0].#subform[12].Name_Of_Provider[#{ITERATOR}]"
          },
          'startDate' => {
            'month' => {
              iterator_offset: ->(iterator) { iterator + 2 },
              key: "form1[0].#subform[12].Provider_Start_Date_Month[#{ITERATOR}]"
            },
            'day' => {
              iterator_offset: ->(iterator) { iterator + 2 },
              key: "form1[0].#subform[12].Provider_Start_Date_Day[#{ITERATOR}]"
            },
            'year' => {
              iterator_offset: ->(iterator) { iterator + 2 },
              key: "form1[0].#subform[12].Provider_Start_Date_Year[#{ITERATOR}]"
            }
          },
          'endDate' => {
            'month' => {
              iterator_offset: ->(iterator) { iterator + 2 },
              key: "form1[0].#subform[12].Provider_End_Date_Month[#{ITERATOR}]"
            },
            'day' => {
              iterator_offset: ->(iterator) { iterator + 2 },
              key: "form1[0].#subform[12].Provider_End_Date_Day[#{ITERATOR}]"
            },
            'year' => {
              iterator_offset: ->(iterator) { iterator + 2 },
              key: "form1[0].#subform[12].Provider_End_Date_Year[#{ITERATOR}]"
            }
          },
          'monthlyAmount' => {
            'thousands' => {
              iterator_offset: lambda { |iterator| # very mangled field names, beware
                if iterator <= 3
                  iterator + 6
                else
                  iterator + 5
                end
              },
              key_from_iterator: lambda { |iterator|
                case iterator
                when 3 then 'form1[0].#subform[12].Amount_You_Pay[0]'
                else "form1[0].#subform[12].Amount_Paid_Monthly[#{ITERATOR}]"
                end
              }
            },
            'dollars' => {
              iterator_offset: ->(iterator) { (iterator * 2) + 12 },
              key: "form1[0].#subform[12].Amount[#{ITERATOR}]"
            },
            'cents' => {
              iterator_offset: ->(iterator) { (iterator * 2) + 13 },
              key: "form1[0].#subform[12].Amount[#{ITERATOR}]"
            }
          },
          'hourlyRate' => {
            iterator_offset: ->(iterator) { iterator + 2 },
            key: "form1[0].#subform[12].Payment_Rate_Per_Hour[#{ITERATOR}]"
          },
          'weeklyHours' => {
            key: "form1[0].#subform[12].Average_Hours_Worked_Per_Week[#{ITERATOR}]"
          }
        }
      }.freeze

      # expand care expenses
      def expand(form_data = {})
        form_data['careExpenses'] ||= []
        form_data['additionalCareExpenses'] = form_data['careExpenses'].drop(2).map { |r| expand_recipient(r) }
        form_data
      end

      # expand recipients
      def expand_recipient(recipient)
        recipient['recipient'] = Constants::RECIPIENTS[recipient['recipient']] || 'Off'
        recipient['startDate'] = split_date(recipient['startDate'])
        recipient['endDate'] = split_date(recipient['endDate'])
        recipient['monthlyAmount'] = split_currency_amount_sm(recipient['monthlyAmount'], { 'thousands' => 3 })
        recipient
      end
    end
  end
end
