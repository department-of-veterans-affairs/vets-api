# frozen_string_literal: true

require 'medical_expense_reports/pdf_fill/section'

require_relative '../../constants'

module MedicalExpenseReports
  module PdfFill
    # Section IV: In-Home Care And Care Facility Expenses
    class Section4 < Section
      # Section configuration hash
      KEY = {
        'primaryCareExpenses' => {
          limit: 2,
          first_key: 'recipient',
          'recipient' => {
            key: "form1[0].#subform[9].RadioButtonList[#{ITERATOR}]"
          },
          'recipientName' => {
            iterator_offset: ->(iterator) { 1 - iterator }, # careful
            key: "form1[0].#subform[9].Name_Of_Child_Or_Other[#{ITERATOR}]"
          },
          'provider' => {
            key: "form1[0].#subform[9].Name_Of_Provider[#{ITERATOR}]"
          },
          'startDate' => {
            'month' => {
              key: "form1[0].#subform[9].Provider_Start_Date_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "form1[0].#subform[9].Provider_Start_Date_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "form1[0].#subform[9].Provider_Start_Date_Year[#{ITERATOR}]"
            }
          },
          'endDate' => {
            'month' => {
              key: "form1[0].#subform[9].Provider_End_Date_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "form1[0].#subform[9].Provider_End_Date_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "form1[0].#subform[9].Provider_End_Date_Year[#{ITERATOR}]"
            }
          },
          'monthlyAmount' => {
            'thousands' => {
              iterator_offset: ->(iterator) { (iterator * 3) + 1 },
              key: "form1[0].#subform[9].Amount_Paid_Monthly[#{ITERATOR}]"
            },
            'dollars' => {
              iterator_offset: ->(iterator) { iterator * 3 },
              key: "form1[0].#subform[9].Amount_Paid_Monthly[#{ITERATOR}]"
            },
            'cents' => {
              iterator_offset: ->(iterator) { (iterator * 3) + 2 },
              key: "form1[0].#subform[9].Amount_Paid_Monthly[#{ITERATOR}]"
            }
          },
          'hourlyRate' => {
            key: "form1[0].#subform[9].Payment_Rate_Per_Hour[#{ITERATOR}]"
          },
          'weeklyHours' => {
            key: "form1[0].#subform[9].Hours_Worked_Per_Week[#{ITERATOR}]"
          }
        }
      }.freeze

      # expand care expenses
      def expand(form_data = {})
        form_data['careExpenses'] ||= []
        form_data['primaryCareExpenses'] =
          form_data['careExpenses'].take(2).map { |r| expand_recipient(r) } # the rest go on Addendum A
        form_data
      end

      # expand recipient care
      def expand_recipient(recipient)
        recipient['recipient'] = Constants::RECIPIENTS[recipient['recipient']] || 'Off'
        recipient['careDate'] ||= {}
        recipient['startDate'] = split_date(recipient['careDate']['from'])
        recipient['endDate'] = split_date(recipient['careDate']['to'])
        recipient['monthlyAmount'] = split_currency_amount_sm(recipient['monthlyAmount'], { 'thousands' => 3 })
        recipient
      end
    end
  end
end
