# frozen_string_literal: true

module IncomeAndAssets
  ##
  # See pdf_fill/forms/va21p0969.rb
  #
  module Helpers
    include ActiveSupport::NumberHelper

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

    ##
    # Splits a currency amount into parts like cents, dollars, thousands, and optionally millions.
    # Determines whether to use small or large field config based on amount.
    #
    # @param amount [Numeric, nil]
    # @param field_lengths [Hash]
    # @return [Hash]
    #
    def split_currency_amount(amount, field_lengths = {})
      return {} unless amount&.positive?

      if amount < 999_999
        lengths = CURRENCY_LENGTHS_SM.merge(field_lengths)
      elsif amount < 999_999_999
        lengths = CURRENCY_LENGTHS_LG.merge(field_lengths)
      else
        return {}
      end

      fields = lengths.keys
      parts = ActiveSupport::NumberHelper.number_to_currency(amount).to_s.scan(/\d+/)

      result = fields.map.with_index do |field, i|
        [field, get_currency_field(parts, -(i + 1), lengths[field])]
      end.to_h

      # Ensure that thousands and dollars have 3 digits, prefix with zeros if necessary
      %w[thousands dollars].each do |field|
        result[field] = result[field].to_s.rjust(3, '0') if result[field]
      end

      # Remove "thousands" if it's zero AND "millions" doesn't exist
      result.delete('thousands') if result['thousands'].to_i.zero? && !result.key?('millions')

      result
    end

    ##
    # Splits a currency amount into thousands, dollars, and cents.
    #
    # @param amount [Numeric, nil]
    # @param field_lengths [Hash]
    # @return [Hash]
    #
    def split_currency_amount_sm(amount, field_lengths = {})
      return {} if !amount || amount.negative? || amount >= 1_000_000

      lengths = CURRENCY_LENGTHS_SM.merge(field_lengths)
      arr = ActiveSupport::NumberHelper.number_to_currency(amount).to_s.split(/[,.$]/).reject(&:empty?)
      {
        'cents' => get_currency_field(arr, -1, lengths['cents']),
        'dollars' => get_currency_field(arr, -2, lengths['dollars']),
        'thousands' => get_currency_field(arr, -3, lengths['thousands'])
      }
    end

    ##
    # Splits a currency amount into millions, thousands, dollars, and cents.
    #
    # @param amount [Numeric, nil]
    # @param field_lengths [Hash]
    # @return [Hash]
    #
    def split_currency_amount_lg(amount, field_lengths = {})
      return {} if !amount || amount.negative? || amount >= 99_999_999

      lengths = CURRENCY_LENGTHS_LG.merge(field_lengths)
      arr = ActiveSupport::NumberHelper.number_to_currency(amount).to_s.split(/[,.$]/).reject(&:empty?)
      {
        'cents' => get_currency_field(arr, -1, lengths['cents']),
        'dollars' => get_currency_field(arr, -2, lengths['dollars']),
        'thousands' => get_currency_field(arr, -3, lengths['thousands']),
        'millions' => get_currency_field(arr, -4, lengths['millions'])
      }
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
      value = arr.length >= -neg_i ? arr[neg_i] : 0
      format("%0#{field_length}d", value.to_i)
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
