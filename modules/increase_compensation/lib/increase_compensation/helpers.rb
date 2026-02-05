# frozen_string_literal: true

module IncreaseCompensation
  ##
  # See pdf_fill/forms/va218940v1.rb
  #
  module Helpers
    include ActiveSupport::NumberHelper
    include ::PdfFill::Forms::FormHelper

    # Maps a date_range to a hash of from and to dates split into month, day, and year
    #
    # @param date_range [Hash]
    # @return [Hash]
    #
    def map_date_range(date_range)
      return {} if date_range.nil? || date_range['from'].nil?

      {
        'from' => split_date(date_range['from']),
        'to' => split_date(date_range['to'])
      }
    end

    def map_date_range_for_care(date_range)
      return {} if date_range.nil? || date_range['from'].nil?

      {
        'from' => split_date_without_day(date_range['from']),
        'to' => split_date_without_day(date_range['to'])
      }
    end

    # Splits a date string YYYY-MM, YYYY/MM, MM/YYYY, or MM-YYYY into Date hash of `{month:, day:, year:}``.
    #
    # @param year_month_string [String]
    # @return [Hash]
    #
    def split_date_without_day(year_month_string)
      return {} if year_month_string.nil? || year_month_string.blank? || year_month_string.length > 7

      s_date = year_month_string.include?('-') ? year_month_string.split('-') : year_month_string.split('/')
      month = s_date.select { |s| s.length == 2 }
      year = s_date.select { |s| s.length > 2 }
      {
        'month' => month[0],
        'day' => '',
        'year' => year[0]
      }
    end

    ##
    # Format Currency into just thousands and hundreds. example 125,100 => `{ firstThree="125", lastThree="100" }`
    # Amount will be padded so that the value fills space right to left.
    #
    # @param amount [Integer, nil]
    # @return [Hash]
    def split_currency_amount_thousands(amount)
      return {} if amount.nil? || amount.negative? || amount >= 1_000_000

      if amount > 999
        thousands = amount.to_s[..-4]
        hundreds = amount.to_s[-3..]
        {
          'firstThree' => thousands.to_s.rjust(3),
          'lastThree' => hundreds
        }
      else
        {
          'lastThree' => amount.to_s.rjust(3)
        }
      end
    end

    ##
    # Map a boolean to custom text responses. Some pdf include text with the YES/NO field,
    # for example `YES (If &quot;Yes,&quot; explain in Item 26, &quot;Remarks&quot;)`
    #
    # @param bool_value [Boolean]
    # @param custom_yes_value [String]
    # @param custom_no_value [String]
    # @return [String]
    #
    def format_custom_boolean(bool_value, custom_yes_value = 'YES', custom_no_value = 'NO')
      return 'Off' if bool_value.nil? || bool_value == ''

      bool_value ? custom_yes_value : custom_no_value
    end

    ##
    # form has text field with two lines, wrap text to next line
    #
    # @param string [String]
    # @param key_name [String]
    # @param limit [Integer]
    # return [Hash]
    #
    def two_line_overflow(string, key_name, split_limit)
      return {} if string.blank?

      if string.length > split_limit
        {
          "#{key_name}1" => string[..(split_limit - 1)],
          "#{key_name}2" => string[split_limit..]
        }
      else
        {
          "#{key_name}1" => string
        }
      end
    end

    ##
    # If the care arrays are exactly 1 item, this formats if to fit the form sections
    #
    #  @param care_item [Hash]
    def format_first_care_item(care_item)
      date_key = care_item.key?('doctorsTreatmentDates') ? 'doctorsTreatmentDates' : 'hospitalTreatmentDates'
      namekey = care_item.key?('nameAndAddressOfDoctor') ? 'nameAndAddressOfDoctor' : 'nameAndAddressOfHospital'
      dates = if care_item[date_key].length > 1
                {
                  'from' => {
                    'year' => care_item[date_key].map { |td| "from: #{td['from']}, to: #{td['to']}\n" }.join
                  }
                }
              else
                map_date_range_for_care(care_item[date_key].first)
              end
      is_va = care_item['inVANetwork'] ? 'VA' : 'Non-VA'
      [
        dates,
        "#{is_va} - #{care_item[namekey]}"
      ]
    end

    ##
    # If the care arrays have more than 1 entry, this formats it for the overflow pages
    #
    # @param care_info_array [Array]
    # @param is_doc [Bool]
    def overflow_doc_and_hospitals(care_info_array, is_doc)
      return nil if care_info_array.nil? || is_doc.nil?

      key_name_address = is_doc ? 'nameAndAddressOfDoctor' : 'nameAndAddressOfHospital'
      key_treatment = is_doc ? 'doctorsTreatmentDates' : 'hospitalTreatmentDates'
      care_info_array.map do |info|
        "#{info['inVANetwork'] ? 'VA' : 'Non-VA'} - #{info[key_name_address]}\n" \
          "#{info['relatedDisability'] ? "Treated for: #{info['relatedDisability'].join(', ')}\n" : ''}" \
          "#{info[key_treatment].map { |td| "From: #{td['from']}, To: #{td['to']}\n" }.join}"
      end
    end

    def resolve_boolean_checkbox(bool_value)
      case bool_value
      when true
        'YES'
      when false
        'NO'
      else
        'OFF'
      end
    end
  end
end
