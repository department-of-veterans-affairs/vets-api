# frozen_string_literal: true

module IncomeAndAssets
  class Helpers
    include ActiveSupport::NumberHelper

    # Format a YYYY-MM-DD date string to MM/DD/YYYY
    #
    # @param date_string [String] a date string in the format YYYY-MM-DD
    #
    # @return [String] a date string in the format MM/DD/YYYY
    #
    def self.format_date_to_mm_dd_yyyy(date_string)
      return nil if date_string.blank?

      Date.parse(date_string).strftime('%m/%d/%Y')
    end

    def self.split_currency_amount(amount)
      return {} if !amount || amount.negative? || amount >= 100_000

      arr = ActiveSupport::NumberHelper.number_to_currency(amount).to_s.split(/[,.$]/).reject(&:empty?)
      {
        'cents' => get_currency_field(arr, -1, 2),
        'dollars' => get_currency_field(arr, -2, 3),
        'thousands' => get_currency_field(arr, -3, 2)
      }
    end

    def self.split_account_value(amount)
      return {} if !amount || amount.negative? || amount >= 10_000_000

      arr = ActiveSupport::NumberHelper.number_to_currency(amount).to_s.split(/[,.$]/).reject(&:empty?)
      {
        'cents' => get_currency_field(arr, -1, 2),
        'dollars' => get_currency_field(arr, -2, 3),
        'thousands' => get_currency_field(arr, -3, 3),
        'millions' => get_currency_field(arr, -4, 2)
      }
    end

    def self.get_currency_field(arr, neg_i, field_length)
      value = arr.length >= -neg_i ? arr[neg_i] : 0
      format("%0#{field_length}d", value.to_i)
    end
  end
end
