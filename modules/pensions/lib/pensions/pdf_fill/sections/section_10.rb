# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section X: Information about your unreimbursed medical expenses
    class Section10 < Section
      # Section configuration hash
      KEY = {
        # 10a
        'hasAnyExpenses' => {
          key: 'Has_Any_Expenses_Yes_No'
        },
        # 10b-d Care Expenses
        'careExpenses' => {
          limit: 3,
          item_label: 'Care expense',
          first_key: 'childName',
          # (1) Recipient
          'recipients' => {
            key: "Care_Expenses.Recipient[#{ITERATOR}]"
          },
          'recipientsOverflow' => {
            question_num: 10,
            question_suffix: 'A',
            question_label: 'Care Expense Recipient',
            question_text: 'CARE EXPENSE RECIPIENT'
          },
          'childName' => {
            key: "Care_Expenses.Child_Specify[#{ITERATOR}]",
            limit: 45,
            question_num: 10,
            question_suffix: 'A',
            question_label: 'Care Expense Child Name',
            question_text: 'CARE EXPENSE CHILD NAME'
          },
          # (2) Provider
          'provider' => {
            key: "Care_Expenses.Name_Of_Provider[#{ITERATOR}]",
            limit: 70,
            question_num: 10,
            question_suffix: 'A',
            question_label: 'Care Expense Provider Name',
            question_text: 'CARE EXPENSE PROVIDER NAME'
          },
          'careType' => {
            key: "Care_Expenses.Care_Type[#{ITERATOR}]"
          },
          'careTypeOverflow' => {
            question_num: 10,
            question_suffix: 'A',
            question_label: 'Care Type',
            question_text: 'CARE TYPE'
          },
          # (3) Rate Per Hour
          'ratePerHour' => {
            'part_one' => {
              key: "Care_Expenses.Rate_Per_Hour_Amount[#{ITERATOR}]"
            },
            'part_cents' => {
              key: "Care_Expenses.Rate_Per_Hour_Amount_Cents[#{ITERATOR}]"
            }
          },
          'ratePerHourOverflow' => {
            question_num: 10,
            question_suffix: 'A',
            question_label: 'Care Expense Rate Per Hour',
            question_text: 'CARE EXPENSE RATE PER HOUR'
          },
          'hoursPerWeek' => {
            limit: 3,
            question_num: 10,
            question_suffix: 'A',
            question_label: 'Provider Hours Worked Per Week',
            question_text: 'PROVIDER HOURS WORKED PER WEEK',
            key: "Care_Expenses.Hours_Worked_Per_Week[#{ITERATOR}]"
          },
          # (4) Provider Start/End Dates
          'careDateRange' => {
            'from' => {
              'month' => {
                key: "Care_Expenses.Provider_Start_Date_Month[#{ITERATOR}]"
              },
              'day' => {
                key: "Care_Expenses.Provider_Start_Date_Day[#{ITERATOR}]"
              },
              'year' => {
                key: "Care_Expenses.Provider_Start_Date_Year[#{ITERATOR}]"
              }
            },
            'to' => {
              'month' => {
                key: "Care_Expenses.Provider_End_Date_Month[#{ITERATOR}]"
              },
              'day' => {
                key: "Care_Expenses.Provider_End_Date_Day[#{ITERATOR}]"
              },
              'year' => {
                key: "Care_Expenses.Provider_End_Date_Year[#{ITERATOR}]"
              }
            }
          },
          'careDateRangeOverflow' => {
            question_num: 10,
            question_suffix: 'A',
            question_label: 'Date Range Care Received',
            question_text: 'DATE RANGE CARE RECEIVED'
          },
          'noCareEndDate' => {
            key: "Care_Expenses.CheckBox_No_End_Date[#{ITERATOR}]"
          },
          # (5) Payment Frequency
          'paymentFrequency' => {
            key: "Care_Expenses.Payment_Frequency[#{ITERATOR}]"
          },
          'paymentFrequencyOverflow' => {
            question_num: 10,
            question_suffix: 'A',
            question_label: 'Care Expense Payment Frequency',
            question_text: 'CARE EXPENSE PAYMENT FREQUENCY'
          },
          # (6) Rate Per Frequency
          'paymentAmount' => {
            'part_two' => {
              key: "Care_Expenses.Rate_Per_Frequency_Amount_First_Three[#{ITERATOR}]"
            },
            'part_one' => {
              key: "Care_Expenses.Rate_Per_Frequency_Amount_Last_Three[#{ITERATOR}]"
            },
            'part_cents' => {
              key: "Care_Expenses.Rate_Per_Frequency_Amount_Cents[#{ITERATOR}]"
            }
          },
          'paymentAmountOverflow' => {
            question_num: 10,
            question_suffix: 'A',
            question_label: 'Care Expense Payment Amount',
            question_text: 'CARE EXPENSE PAYMENT AMOUNT'
          }
        },
        # 10e-j Medical Expenses
        'medicalExpenses' => {
          limit: 6,
          item_label: 'Medical expense',
          first_key: 'childName',
          # (1) Recipient
          'recipients' => {
            key: "Med_Expenses.Recipient[#{ITERATOR}]"
          },
          'recipientsOverflow' => {
            question_num: 10,
            question_suffix: 'B',
            question_label: 'Medical Expense Recipient',
            question_text: 'MEDICAL EXPENSE RECIPIENT'
          },
          'childName' => {
            key: "Med_Expenses.Child_Specify[#{ITERATOR}]",
            limit: 45,
            question_num: 10,
            question_suffix: 'B',
            question_label: 'Medical Expense Child Name',
            question_text: 'MEDICAL EXPENSE CHILD NAME'
          },
          # (2) Provider
          'provider' => {
            key: "Med_Expenses.Paid_To[#{ITERATOR}]",
            limit: 108,
            question_num: 10,
            question_suffix: 'B',
            question_label: 'Medical Expense Provider Name',
            question_text: 'MEDICAL EXPENSE PROVIDER NAME'
          },
          # (3) Purpose
          'purpose' => {
            key: "Med_Expenses.Purpose[#{ITERATOR}]",
            limit: 108,
            question_num: 10,
            question_suffix: 'B',
            question_label: 'Medical Expense Purpose',
            question_text: 'MEDICAL EXPENSE PURPOSE'
          },
          # (4) Payment Date
          'paymentDate' => {
            'month' => {
              key: "Med_Expenses.Date_Costs_Incurred_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "Med_Expenses.Date_Costs_Incurred_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "Med_Expenses.Date_Costs_Incurred_Year[#{ITERATOR}]"
            }
          },
          'paymentDateOverflow' => {
            question_num: 10,
            question_suffix: 'B',
            question_label: 'Medical Expense Payment Date',
            question_text: 'MEDICAL EXPENSE PAYMENT DATE'
          },
          # (5) Payment Frequency
          'paymentFrequency' => {
            key: "Med_Expenses.Payment_Frequency[#{ITERATOR}]"
          },
          'paymentFrequencyOverflow' => {
            question_num: 10,
            question_suffix: 'B',
            question_label: 'Medical Expense Payment Frequency',
            question_text: 'MEDICAL EXPENSE PAYMENT FREQUENCY'
          },
          # (6) Rate Per Frequency
          'paymentAmount' => {
            'part_two' => {
              limit: 2,
              key: "Med_Expenses.Amount_First_Two[#{ITERATOR}]"
            },
            'part_one' => {
              key: "Med_Expenses.Amount_Last_Three[#{ITERATOR}]"
            },
            'part_cents' => {
              key: "Med_Expenses.Amount_Cents[#{ITERATOR}]"
            }
          },
          'paymentAmountOverflow' => {
            question_num: 10,
            question_suffix: 'B',
            question_label: 'Medical Expense Payment Amount',
            question_text: 'MEDICAL EXPENSE PAYMENT AMOUNT'
          }
        }
      }.freeze

      ##
      # Expands the medical and care expenses information by:
      # - Converting hasAnyExpenses to radio button format
      # - Merging care expenses data
      # - Merging medical expenses data
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        form_data['hasAnyExpenses'] =
          to_radio_yes_no(form_data['hasCareExpenses'] || form_data['hasMedicalExpenses'])
        form_data['careExpenses'] = merge_care_expenses(form_data['careExpenses'])
        form_data['medicalExpenses'] = merge_medical_expenses(form_data['medicalExpenses'])
      end

      # Map over the care expenses and expand the data out.
      def merge_care_expenses(care_expenses)
        care_expenses&.map do |care_expense|
          care_expense.merge(care_expense_to_hash(care_expense))
        end
      end

      # Expand a care expense data hash.
      def care_expense_to_hash(care_expense)
        {
          'recipients' => Constants::RECIPIENTS[care_expense['recipients']],
          'recipientsOverflow' => care_expense['recipients']&.humanize,
          'careType' => Constants::CARE_TYPES[care_expense['careType']],
          'careTypeOverflow' => care_expense['careType']&.humanize,
          'ratePerHour' => split_currency_amount(care_expense['ratePerHour']),
          'ratePerHourOverflow' => number_to_currency(care_expense['ratePerHour']),
          'hoursPerWeek' => care_expense['hoursPerWeek'].to_s,
          'careDateRange' => {
            'from' => split_date(care_expense.dig('careDateRange', 'from')),
            'to' => split_date(care_expense.dig('careDateRange', 'to'))
          },
          'careDateRangeOverflow' => build_date_range_string(care_expense['careDateRange']),
          'noCareEndDate' => to_checkbox_on_off(care_expense['noCareEndDate']),
          'paymentFrequency' => Constants::PAYMENT_FREQUENCY[care_expense['paymentFrequency']],
          'paymentFrequencyOverflow' => care_expense['paymentFrequency'],
          'paymentAmount' => split_currency_amount(care_expense['paymentAmount']),
          'paymentAmountOverflow' => number_to_currency(care_expense['paymentAmount'])
        }
      end

      # Map over medical expenses and create a set of data.
      def merge_medical_expenses(medical_expenses)
        medical_expenses&.map do |medical_expense|
          medical_expense.merge({
                                  'recipients' => Constants::RECIPIENTS[medical_expense['recipients']],
                                  'recipientsOverflow' => medical_expense['recipients']&.humanize,
                                  'paymentDate' => split_date(medical_expense['paymentDate']),
                                  'paymentDateOverflow' => to_date_string(medical_expense['paymentDate']),
                                  'paymentFrequency' =>
                                    Constants::PAYMENT_FREQUENCY[medical_expense['paymentFrequency']],
                                  'paymentFrequencyOverflow' => medical_expense['paymentFrequency'],
                                  'paymentAmount' => split_currency_amount(medical_expense['paymentAmount']),
                                  'paymentAmountOverflow' => number_to_currency(
                                    medical_expense['paymentAmount']
                                  )
                                })
        end
      end
    end
  end
end
