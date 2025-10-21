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

    # NOTE: in regards to the checkbox_value and radio_yesno helpers below,
    #   HexaPDF is more strict about the values it accepts for checkboxes and radio buttons
    #   than PDFtk. HexaPDF wants true/false for checkboxes and strings/symbols for radio buttons.

    ##
    # Converts a value to a checkbox-compatible boolean.
    #
    # @param value [Any]
    # @return [Boolean]
    #
    def checkbox_value(value)
      value ? '1' : 'Off'
    end

    ##
    # Converts a value to a radio button-compatible 0 or 1.
    #
    # @param value [Any]
    # @return [Integer] 0 for 'yes', 1 for 'no'
    #
    def radio_yesno(value)
      value ? 0 : 1
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
