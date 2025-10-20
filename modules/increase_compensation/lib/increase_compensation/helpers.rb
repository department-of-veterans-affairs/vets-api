# frozen_string_literal: true

module IncreaseCompensation
  ##
  # See pdf_fill/forms/va218940v1.rb
  #
  module Helpers
    include ActiveSupport::NumberHelper
    include ::PdfFill::Forms::FormHelper

    # Small currency lengths
    CURRENCY_LENGTHS_SM = { 'cents' => 2, 'dollars' => 3, 'thousands' => 2 }.freeze

    # Large currency lengths
    CURRENCY_LENGTHS_LG = { 'cents' => 2, 'dollars' => 3, 'thousands' => 3, 'millions' => 2 }.freeze

    # Format a YYYY-MM-DD date string to MM/DD/YYYY
    #
    # @param date_string [String]
    # @return [String]
    #
    def format_date_to_mm_dd_yyyy(date_string)
      return nil if date_string.blank?

      Date.parse(date_string).strftime('%m/%d/%Y')
    end

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

    ##
    # Format Currency into just thousands and hundreds `{ firstThree="100", lastThree="100" }``
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
    # Splits a currency amount into thousands, dollars, and cents.
    #
    # @param amount [Numeric, nil]
    # @param field_lengths [Hash]
    # @return [Hash]
    #
    def split_currency_amount_sm(amount, field_lengths = {})
      return {} if !amount&.nonzero? || amount.negative? || amount >= 1_000_000

      lengths = CURRENCY_LENGTHS_SM.merge(field_lengths)
      arr = ActiveSupport::NumberHelper.number_to_currency(amount).to_s.split(/[,.$]/).reject(&:empty?)
      amount_hash = {
        'cents' => get_currency_field(arr, -1, lengths['cents']),
        'dollars' => get_currency_field(arr, -2, lengths['dollars']),
        'thousands' => get_currency_field(arr, -3, lengths['thousands'])
      }.compact

      return {} if amount_hash.any? { |k, v| v.size > lengths[k] }

      amount_hash
    end

    ##
    # Splits a currency amount into millions, thousands, dollars, and cents.
    #
    # @param amount [Numeric, nil]
    # @param field_lengths [Hash]
    # @return [Hash]
    #
    def split_currency_amount_lg(amount, field_lengths = {})
      return {} if !amount&.nonzero? || amount.negative? || amount >= 99_999_999

      lengths = CURRENCY_LENGTHS_LG.merge(field_lengths)
      arr = ActiveSupport::NumberHelper.number_to_currency(amount).to_s.split(/[,.$]/).reject(&:empty?)
      amount_hash = {
        'cents' => get_currency_field(arr, -1, lengths['cents']),
        'dollars' => get_currency_field(arr, -2, lengths['dollars']),
        'thousands' => get_currency_field(arr, -3, lengths['thousands']),
        'millions' => get_currency_field(arr, -4, lengths['millions'])
      }.compact

      return {} if amount_hash.any? { |k, v| v.size > lengths[k] }

      amount_hash
    end

    ##
    # Retrieves a specific portion of a currency value and formats it to a fixed length.
    #
    # @param arr [Array<String>]
    # @param neg_i [Integer]
    # @param field_length [Integer]
    # @return [String]
    #
    def get_currency_field(arr, neg_i, field_length)
      value = arr.length >= -neg_i ? arr[neg_i] : nil
      (field_length - value.length).times { value = value.dup.prepend(' ') } if value
      value
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
    # param string [String]
    # param key_name [String]
    # param limit [Integer]
    # return [Hash]
    #
    def two_line_overflow(string, key_name, limit)
      return {} if string.blank?

      if string.length > limit
        {
          "#{key_name}1" => string[..(limit - 1)],
          "#{key_name}2" => string[limit..]
        }
      else
        {
          "#{key_name}1" => string
        }
      end
    end

    ##
    # Converts a hash's values into a space-separated string.
    #
    # @param hash [Hash]
    # @return [String]
    #
    def change_hash_to_string(hash)
      return '' if hash.blank?

      hash.values.join(' ')
    end
  end
end
