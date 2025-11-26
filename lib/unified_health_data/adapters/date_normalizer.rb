# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    module DateNormalizer
      # Normalizes date values to a consistent ISO 8601 format for reliable sorting
      # Year-only dates (e.g., "2024") are converted to "2024-01-01T00:00:00Z"
      # Dates without time are converted to include T00:00:00Z for consistent comparison
      # Nil dates are converted to "1900-01-01T00:00:00Z" to sort at the end (descending)
      #
      # @param date_value [String, nil] The date value to normalize
      # @return [String] Normalized ISO 8601 date string
      def normalize_date_for_sorting(date_value)
        return '1900-01-01T00:00:00Z' if date_value.nil?
        return "#{date_value}-01-01T00:00:00Z" if date_value.match?(/^\d{4}$/) # Year only
        return "#{date_value}T00:00:00Z" if date_value.match?(/^\d{4}-\d{2}-\d{2}$/) # Date without time

        date_value # Pass through dates that already have time (e.g., "2024-11-08T10:00:00Z")
      end
    end
  end
end
