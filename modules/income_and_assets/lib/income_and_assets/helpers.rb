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
    # Splits a currency amount into thousands, dollars, and cents.
    #
    # @param amount [Numeric, nil]
    # @param field_lengths [Hash]
    # @return [Hash]
    #
    def split_currency_amount_sm(amount, field_lengths = {})
      return {} if !amount || amount.negative? || amount >= 100_000

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
      return {} if !amount || amount.negative? || amount >= 10_000_000

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
