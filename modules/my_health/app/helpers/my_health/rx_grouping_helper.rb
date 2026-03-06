# frozen_string_literal: true

module MyHealth
  module RxGroupingHelper
    SUFFIX_PATTERN = /[A-Z]+$/
    SINGLE_LETTER_SUFFIX = /[A-Z]$/

    def group_prescriptions(prescriptions)
      return [] if prescriptions.blank?

      # Pre-compute base numbers once - O(n)
      # Note: Use SINGLE_LETTER_SUFFIX for grouping to match original behavior
      rx_with_base = prescriptions.map do |rx|
        base_number = rx.prescription_number.sub(SINGLE_LETTER_SUFFIX, '')
        group_key = "#{base_number}-#{rx.station_number}"
        [rx, group_key]
      end

      # Group by base prescription number + station in O(n)
      groups = rx_with_base.group_by { |_, group_key| group_key }

      # Process each group - total O(n) since each prescription processed once
      groups.map do |_key, members|
        rxs = members.map(&:first)

        if rxs.length == 1
          rxs.first
        else
          # Find the one with highest prescription number (latest renewal)
          sorted = rxs.sort_by(&:prescription_number).reverse
          base = sorted.first
          related = sorted[1..]

          # Sort related prescriptions by suffix (descending) then by base number
          related_sorted = sort_related_prescriptions(related)

          base.grouped_medications = related_sorted
          base
        end
      end
    end

    def get_single_rx_from_grouped_list(prescriptions, id)
      grouped_list = group_prescriptions(prescriptions)
      grouped_list.find { |rx| rx.prescription_id == id }
    end

    def count_grouped_prescriptions(prescriptions)
      return 0 if prescriptions.nil?

      # Use the optimized group_prescriptions and just count the results
      # This is O(n) instead of O(n²)
      group_prescriptions(prescriptions.dup).length
    end

    private

    def sort_related_prescriptions(related_prescriptions)
      related_prescriptions.sort do |rx1, rx2|
        suffix1 = rx1.prescription_number[SUFFIX_PATTERN] || ''
        suffix2 = rx2.prescription_number[SUFFIX_PATTERN] || ''

        if suffix1 == suffix2
          base_number1 = rx1.prescription_number.sub(SUFFIX_PATTERN, '').to_i
          base_number2 = rx2.prescription_number.sub(SUFFIX_PATTERN, '').to_i
          base_number1 <=> base_number2
        else
          suffix2 <=> suffix1
        end
      end
    end

    module_function :group_prescriptions
  end
end
