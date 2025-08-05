# frozen_string_literal: true

module Pensions
  module PdfFill
    # Helpers used for PDF mapping
    module Helpers
      # Convert a date to a string
      def to_date_string(date)
        date_hash = split_date(date)
        return unless date_hash

        "#{date_hash['month']}-#{date_hash['day']}-#{date_hash['year']}"
      end

      # Build a date range string from a date range object
      def build_date_range_string(date_range)
        "#{to_date_string(date_range['from'])} - #{to_date_string(date_range['to']) || 'No End Date'}"
      end

      # Split up currency amounts to three parts.
      def split_currency_amount(amount)
        return {} if amount.nil? || amount.negative? || amount >= 10_000_000

        number_map = {
          1 => 'one',
          2 => 'two',
          3 => 'three'
        }

        arr = number_to_currency(amount).to_s.split(/[,.$]/).reject(&:empty?)
        split_hash = { 'part_cents' => arr.last }
        arr.pop
        arr.each_with_index { |x, i| split_hash["part_#{number_map[arr.length - i]}"] = x }
        split_hash
      end

      # Convert an objects truthiness to a radio on/off.
      def to_checkbox_on_off(obj)
        obj ? 1 : 'Off'
      end

      # Convert an objects truthiness to a radio yes/no.
      def to_radio_yes_no(obj)
        obj ? 1 : 2
      end
    end
  end
end
