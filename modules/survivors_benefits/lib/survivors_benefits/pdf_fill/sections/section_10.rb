# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

module SurvivorsBenefits
  module PdfFill
    # Section X: Information About Your Medical Or Other Expense
    class Section10 < Section
      include ::PdfFill::Forms::FormHelper
      include Helpers

      CARE_CONFIGS = [
        {
          recipient_field: "form1[0].#subform[215].RadioButtonList[34]",
          recipient_values: {
            'SURVIVING_SPOUSE' => '1',
            'OTHER' => '2',
            'CHILD' => '2'
          },
          recipient_other_field: "form1[0].#subform[215].OTHER_Specify[0]",
          provider_field: "form1[0].#subform[215].Name_Of_Provider_And_Type_Of_Care[0]",
          care_type_field: "form1[0].#subform[215].RadioButtonList[35]",
          care_type_values: {
            'CARE_FACILITY' => '1',
            'IN_HOME_CARE_ATTENDANT' => '2',
            'IN_HOME_CARE_PROVIDER' => '2'
          },
          rate_field: "form1[0].#subform[215].Payment_Rate_Worked_Per_Week[0]",
          hours_field: "form1[0].#subform[215].Hours_Worked_Per_Week[0]",
          date_from_fields: {
            month: "form1[0].#subform[215].Date_Month[12]",
            day: "form1[0].#subform[215].Date_Day[12]",
            year: "form1[0].#subform[215].Date_Year[12]"
          },
          date_to_fields: {
            month: "form1[0].#subform[215].Date_Month[11]",
            day: "form1[0].#subform[215].Date_Day[11]",
            year: "form1[0].#subform[215].Date_Year[11]"
          },
          no_end_field: "form1[0].#subform[215].CheckBox_No_End_Date[0]",
          payment_frequency_field: "form1[0].#subform[215].RadioButtonList[36]",
          payment_frequency_values: {
            'MONTHLY' => '1',
            'ONCE_MONTH' => '1',
            'ANNUALLY' => '2',
            'ONCE_YEAR' => '2'
          },
          payment_amount_fields: {
            thousands: "form1[0].#subform[215].Total_Annual_Earnings_Amount[8]",
            dollars: "form1[0].#subform[215].Total_Annual_Earnings_Amount[7]",
            cents: "form1[0].#subform[215].Total_Annual_Earnings_Amount[9]"
          }
        },
        {
          recipient_field: "form1[0].#subform[216].RadioButtonList[49]",
          recipient_values: {
            'SURVIVING_SPOUSE' => '1',
            'OTHER' => '2',
            'CHILD' => '2'
          },
          recipient_other_field: "form1[0].#subform[216].Other_Specify[1]",
          provider_field: "form1[0].#subform[216].Name_Of_Provider_And_Type_Of_Care[2]",
          care_type_field: "form1[0].#subform[216].RadioButtonList[51]",
          care_type_values: {
            'CARE_FACILITY' => '2',
            'IN_HOME_CARE_ATTENDANT' => '4',
            'IN_HOME_CARE_PROVIDER' => '4'
          },
          rate_field: "form1[0].#subform[216].Payment_Rate_Worked_Per_Week[2]",
          hours_field: "form1[0].#subform[216].Hours_Worked_Per_Week[2]",
          date_from_fields: {
            month: "form1[0].#subform[216].Date_Month[16]",
            day: "form1[0].#subform[216].Date_Day[16]",
            year: "form1[0].#subform[216].Date_Year[16]"
          },
          date_to_fields: {
            month: "form1[0].#subform[216].Date_Month[15]",
            day: "form1[0].#subform[216].Date_Day[15]",
            year: "form1[0].#subform[216].Date_Year[15]"
          },
          no_end_field: "form1[0].#subform[216].CheckBox_No_End_Date[2]",
          payment_frequency_field: "form1[0].#subform[216].RadioButtonList[50]",
          payment_frequency_values: {
            'MONTHLY' => '1',
            'ONCE_MONTH' => '1',
            'ANNUALLY' => '2',
            'ONCE_YEAR' => '2'
          },
          payment_amount_fields: {
            thousands: "form1[0].#subform[216].Total_Annual_Earnings_Amount[14]",
            dollars: "form1[0].#subform[216].Total_Annual_Earnings_Amount[13]",
            cents: "form1[0].#subform[216].Total_Annual_Earnings_Amount[15]"
          }
        },
        {
          recipient_field: "form1[0].#subform[216].RadioButtonList[48]",
          recipient_values: {
            'SURVIVING_SPOUSE' => '1',
            'OTHER' => '2',
            'CHILD' => '2'
          },
          recipient_other_field: "form1[0].#subform[216].Other_Specify[0]",
          provider_field: "form1[0].#subform[216].Name_Of_Provider_And_Type_Of_Care[1]",
          care_type_field: "form1[0].#subform[216].RadioButtonList[46]",
          care_type_values: {
            'CARE_FACILITY' => '2',
            'IN_HOME_CARE_ATTENDANT' => '4',
            'IN_HOME_CARE_PROVIDER' => '4'
          },
          rate_field: "form1[0].#subform[216].Payment_Rate_Worked_Per_Week[1]",
          hours_field: "form1[0].#subform[216].Hours_Worked_Per_Week[1]",
          date_from_fields: {
            month: "form1[0].#subform[216].Date_Month[13]",
            day: "form1[0].#subform[216].Date_Day[13]",
            year: "form1[0].#subform[216].Date_Year[13]"
          },
          date_to_fields: {
            month: "form1[0].#subform[216].Date_Month[14]",
            day: "form1[0].#subform[216].Date_Day[14]",
            year: "form1[0].#subform[216].Date_Year[14]"
          },
          no_end_field: "form1[0].#subform[216].CheckBox_No_End_Date[1]",
          payment_frequency_field: "form1[0].#subform[216].RadioButtonList[47]",
          payment_frequency_values: {
            'MONTHLY' => '1',
            'ONCE_MONTH' => '1',
            'ANNUALLY' => '2',
            'ONCE_YEAR' => '2'
          },
          payment_amount_fields: {
            thousands: "form1[0].#subform[216].Total_Annual_Earnings_Amount[11]",
            dollars: "form1[0].#subform[216].Total_Annual_Earnings_Amount[12]",
            cents: "form1[0].#subform[216].Total_Annual_Earnings_Amount[10]"
          }
        }
      ].freeze

      CARE_EXPENSE_COUNT = CARE_CONFIGS.length

      MEDICAL_CONFIGS = [
        {
          recipient_field: "form1[0].#subform[216].RadioButtonList[53]",
          child_field: "form1[0].#subform[216].CHILD_EXPENSES[0]",
          provider_field: "form1[0].#subform[216].Name_Of_Provider[0]",
          purpose_field: "form1[0].#subform[216].PURPOSE[0]",
          date_fields: {
            month: "form1[0].#subform[216].Date_Month[17]",
            day: "form1[0].#subform[216].Date_Day[17]",
            year: "form1[0].#subform[216].Date_Year[17]"
          },
          payment_frequency_field: "form1[0].#subform[216].RadioButtonList[54]",
          amount_fields: {
            thousands: "form1[0].#subform[216].Amount_You_Pay[1]",
            dollars: "form1[0].#subform[216].Amount_You_Pay[0]",
            cents: "form1[0].#subform[216].Amount_You_Pay[2]"
          }
        },
        {
          recipient_field: "form1[0].#subform[216].RadioButtonList[55]",
          child_field: "form1[0].#subform[216].CHILD_EXPENSES[1]",
          provider_field: "form1[0].#subform[216].Name_Of_Provider[1]",
          purpose_field: "form1[0].#subform[216].PURPOSE[1]",
          date_fields: {
            month: "form1[0].#subform[216].Date_Month[18]",
            day: "form1[0].#subform[216].Date_Day[18]",
            year: "form1[0].#subform[216].Date_Year[18]"
          },
          payment_frequency_field: "form1[0].#subform[216].RadioButtonList[56]",
          amount_fields: {
            thousands: "form1[0].#subform[216].Amount_You_Pay[4]",
            dollars: "form1[0].#subform[216].Amount_You_Pay[3]",
            cents: "form1[0].#subform[216].Amount_You_Pay[5]"
          }
        },
        {
          recipient_field: "form1[0].#subform[216].RadioButtonList[57]",
          child_field: "form1[0].#subform[216].CHILD_EXPENSES[2]",
          provider_field: "form1[0].#subform[216].Name_Of_Provider[2]",
          purpose_field: "form1[0].#subform[216].PURPOSE[2]",
          date_fields: {
            month: "form1[0].#subform[216].Date_Month[19]",
            day: "form1[0].#subform[216].Date_Day[19]",
            year: "form1[0].#subform[216].Date_Year[19]"
          },
          payment_frequency_field: "form1[0].#subform[217].RadioButtonList[58]",
          amount_fields: {
            thousands: "form1[0].#subform[216].Amount_You_Pay[7]",
            dollars: "form1[0].#subform[216].Amount_You_Pay[6]",
            cents: "form1[0].#subform[216].Amount_You_Pay[8]"
          }
        },
        {
          recipient_field: "form1[0].#subform[217].RadioButtonList[59]",
          child_field: "form1[0].#subform[217].CHILD_EXPENSES[3]",
          provider_field: "form1[0].#subform[217].Name_Of_Provider[3]",
          purpose_field: "form1[0].#subform[217].PURPOSE[3]",
          date_fields: {
            month: "form1[0].#subform[217].Date_Month[20]",
            day: "form1[0].#subform[217].Date_Day[20]",
            year: "form1[0].#subform[217].Date_Year[20]"
          },
          payment_frequency_field: "form1[0].#subform[217].RadioButtonList[60]",
          amount_fields: {
            thousands: "form1[0].#subform[217].Amount_You_Pay[10]",
            dollars: "form1[0].#subform[217].Amount_You_Pay[9]",
            cents: "form1[0].#subform[217].Amount_You_Pay[11]"
          }
        },
        {
          recipient_field: "form1[0].#subform[217].RadioButtonList[61]",
          child_field: "form1[0].#subform[217].CHILD_EXPENSES[4]",
          provider_field: "form1[0].#subform[217].Name_Of_Provider[4]",
          purpose_field: "form1[0].#subform[217].PURPOSE[4]",
          date_fields: {
            month: "form1[0].#subform[217].Date_Month[21]",
            day: "form1[0].#subform[217].Date_Day[21]",
            year: "form1[0].#subform[217].Date_Year[21]"
          },
          payment_frequency_field: "form1[0].#subform[217].RadioButtonList[62]",
          amount_fields: {
            thousands: "form1[0].#subform[217].Amount_You_Pay[13]",
            dollars: "form1[0].#subform[217].Amount_You_Pay[12]",
            cents: "form1[0].#subform[217].Amount_You_Pay[14]"
          }
        },
        {
          recipient_field: "form1[0].#subform[217].RadioButtonList[63]",
          child_field: "form1[0].#subform[217].CHILD_EXPENSES[5]",
          provider_field: "form1[0].#subform[217].Name_Of_Provider[5]",
          purpose_field: "form1[0].#subform[217].PURPOSE[5]",
          date_fields: {
            month: "form1[0].#subform[217].Date_Month[22]",
            day: "form1[0].#subform[217].Date_Day[22]",
            year: "form1[0].#subform[217].Date_Year[22]"
          },
          payment_frequency_field: nil,
          amount_fields: {
            thousands: "form1[0].#subform[217].Amount_You_Pay[16]",
            dollars: "form1[0].#subform[217].Amount_You_Pay[15]",
            cents: "form1[0].#subform[217].Amount_You_Pay[17]"
          }
        }
      ].freeze

      MEDICAL_EXPENSE_COUNT = MEDICAL_CONFIGS.length

      KEY = {
        'careExpenses' => {
          limit: CARE_EXPENSE_COUNT,
          first_key: 'recipient',
          'recipient' => {
            key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :recipient_field) }
          },
          'recipientOther' => {
            key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :recipient_other_field) }
          },
          'provider' => {
            key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :provider_field) }
          },
          'careType' => {
            key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :care_type_field) }
          },
          'paymentRate' => {
            key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :rate_field) }
          },
          'hoursPerWeek' => {
            key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :hours_field) }
          },
          'dateRange' => {
            'from' => {
              'month' => {
                key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :date_from_fields, :month) }
              },
              'day' => {
                key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :date_from_fields, :day) }
              },
              'year' => {
                key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :date_from_fields, :year) }
              }
            },
            'to' => {
              'month' => {
                key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :date_to_fields, :month) }
              },
              'day' => {
                key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :date_to_fields, :day) }
              },
              'year' => {
                key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :date_to_fields, :year) }
              }
            }
          },
          'noEndDate' => {
            key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :no_end_field) }
          },
          'paymentFrequency' => {
            key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :payment_frequency_field) }
          },
          'paymentAmount' => {
            'thousands' => {
              key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :payment_amount_fields, :thousands) }
            },
            'dollars' => {
              key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :payment_amount_fields, :dollars) }
            },
            'cents' => {
              key_from_iterator: ->(iterator) { CARE_CONFIGS.dig(iterator, :payment_amount_fields, :cents) }
            }
          }
        },
        'medicalExpenses' => {
          limit: MEDICAL_EXPENSE_COUNT,
          first_key: 'recipient',
          'recipient' => {
            key_from_iterator: ->(iterator) { MEDICAL_CONFIGS.dig(iterator, :recipient_field) }
          },
          'childName' => {
            key_from_iterator: ->(iterator) { MEDICAL_CONFIGS.dig(iterator, :child_field) }
          },
          'provider' => {
            key_from_iterator: ->(iterator) { MEDICAL_CONFIGS.dig(iterator, :provider_field) }
          },
          'purpose' => {
            key_from_iterator: ->(iterator) { MEDICAL_CONFIGS.dig(iterator, :purpose_field) }
          },
          'paymentDate' => {
            'month' => {
              key_from_iterator: ->(iterator) { MEDICAL_CONFIGS.dig(iterator, :date_fields, :month) }
            },
            'day' => {
              key_from_iterator: ->(iterator) { MEDICAL_CONFIGS.dig(iterator, :date_fields, :day) }
            },
            'year' => {
              key_from_iterator: ->(iterator) { MEDICAL_CONFIGS.dig(iterator, :date_fields, :year) }
            }
          },
          'paymentFrequency' => {
            key_from_iterator: ->(iterator) { MEDICAL_CONFIGS.dig(iterator, :payment_frequency_field) }
          },
          'paymentAmount' => {
            'thousands' => {
              key_from_iterator: ->(iterator) { MEDICAL_CONFIGS.dig(iterator, :amount_fields, :thousands) }
            },
            'dollars' => {
              key_from_iterator: ->(iterator) { MEDICAL_CONFIGS.dig(iterator, :amount_fields, :dollars) }
            },
            'cents' => {
              key_from_iterator: ->(iterator) { MEDICAL_CONFIGS.dig(iterator, :amount_fields, :cents) }
            }
          }
        }
      }.freeze

      def expand(form_data = {})
        map_care_expenses(form_data)
        map_medical_expenses(form_data)
        form_data
      end

      private

      def map_care_expenses(form_data)
        care_entries = Array(form_data['careExpenses'])

        form_data['careExpenses'] = CARE_CONFIGS.each_with_index.map do |config, index|
          entry = care_entries[index]
          entry.present? ? transform_care_expense(entry, config) : empty_care_entry
        end
      end

      def map_medical_expenses(form_data)
        medical_entries = Array(form_data['medicalExpenses'])

        form_data['medicalExpenses'] = MEDICAL_CONFIGS.each_with_index.map do |config, index|
          entry = medical_entries[index]
          entry.present? ? transform_medical_expense(entry, config) : empty_medical_entry(config)
        end
      end

      def transform_care_expense(entry, config)
        data = {}
        recipient = entry['recipients'] || entry['recipient']
        normalized_recipient = normalize_enum(recipient)
        data['recipient'] = map_value(recipient, config[:recipient_values])

        other_value = entry['recipientOther'] || entry['childName']
        data['recipientOther'] = recipient_in_other_bucket?(normalized_recipient) ? other_value : nil

        data['provider'] = entry['provider']
        data['careType'] = map_value(entry['careType'], config[:care_type_values])
        data['paymentRate'] = format_numeric_field(entry['ratePerHour'] || entry['paymentRate'])
        data['hoursPerWeek'] = format_numeric_field(entry['hoursPerWeek'])

        data['dateRange'] = {
          'from' => normalize_date(entry.dig('careDateRange', 'from') || entry['providerStartDate']),
          'to' => normalize_date(entry.dig('careDateRange', 'to') || entry['providerEndDate'])
        }

        data['noEndDate'] = to_checkbox(entry['noCareEndDate'])
        data['paymentFrequency'] = map_value(entry['paymentFrequency'], config[:payment_frequency_values])
        amount_parts = split_currency_amount_sm(entry['paymentAmount'], { 'thousands' => 3 })
        data['paymentAmount'] = normalize_amount_fields(amount_parts)
        data
      end

      def transform_medical_expense(entry, config)
        data = {}
        recipient = entry['recipients'] || entry['recipient']
        normalized_recipient = normalize_enum(recipient)
        data['recipient'] = map_value(recipient, medical_recipient_values)
        data['childName'] = normalized_recipient == 'CHILD' ? (entry['childName'] || entry['recipientOther']) : nil
        data['provider'] = entry['provider']
        data['purpose'] = entry['purpose']
        data['paymentDate'] = normalize_date(entry['paymentDate'])
        data['paymentFrequency'] = config[:payment_frequency_field].present? ?
          map_value(entry['paymentFrequency'], medical_frequency_values) : nil
        amount_parts = split_currency_amount_sm(entry['paymentAmount'], { 'thousands' => 3 })
        data['paymentAmount'] = normalize_amount_fields(amount_parts)
        data
      end

      def normalize_date(value)
        return split_date(value) if value.is_a?(String)
        return value.slice('month', 'day', 'year') if value.is_a?(Hash)

        {}
      end

      def map_value(value, mapping)
        return 'Off' if mapping.blank?

        normalized = normalize_enum(value)
        return 'Off' if normalized.blank?

        mapping[normalized] || 'Off'
      end

      def to_checkbox(flag)
        flag ? '1' : 'Off'
      end

      def format_numeric_field(value, length: 3)
        return nil if value.blank?

        number = value.is_a?(String) ? value.to_f : value.to_f
        return nil if number.zero? && value.to_s.strip.empty?

        number.round.to_i.to_s.rjust(length, ' ')
      end

      def normalize_amount_fields(amount_hash)
        return {} if amount_hash.blank?

        normalized = {}
        amount_hash.each do |k, v|
          next if v.blank?

          if k == 'cents'
            normalized[k] = v.to_s.strip.rjust(2, '0')
          else
            normalized[k] = v.to_s.strip.rjust(3, ' ')
          end
        end

        normalized['thousands'] ||= '   '
        normalized['dollars'] ||= '   '
        normalized['cents'] ||= '  '

        normalized
      end

      def normalize_enum(value)
        value.to_s.upcase.gsub(/[^A-Z0-9]+/, '_').gsub(/^_+|_+$/, '')
      end

      def recipient_in_other_bucket?(recipient)
        %w[OTHER CHILD].include?(normalize_enum(recipient))
      end

      def medical_recipient_values
        @medical_recipient_values ||= {
          'SURVIVING_SPOUSE' => '1',
          'VETERAN' => '2',
          'CHILD' => '3'
        }
      end

      def medical_frequency_values
        @medical_frequency_values ||= {
          'MONTHLY' => '1',
          'ANNUALLY' => '2',
          'ONCE_MONTH' => '1',
          'ONCE_YEAR' => '2',
          'ONE_TIME' => '3'
        }
      end

      def empty_care_entry
        {
          'recipient' => 'Off',
          'recipientOther' => nil,
          'provider' => nil,
          'careType' => 'Off',
          'paymentRate' => nil,
          'hoursPerWeek' => nil,
          'dateRange' => {
            'from' => {},
            'to' => {}
          },
          'noEndDate' => 'Off',
          'paymentFrequency' => 'Off',
          'paymentAmount' => {}
        }
      end

      def empty_medical_entry(config)
        base = {
          'recipient' => 'Off',
          'childName' => nil,
          'provider' => nil,
          'purpose' => nil,
          'paymentDate' => {},
          'paymentAmount' => {}
        }
        base['paymentFrequency'] = 'Off' if config[:payment_frequency_field].present?
        base
      end
    end
  end
end
