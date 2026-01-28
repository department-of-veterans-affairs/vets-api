# frozen_string_literal: true

module RepresentationManagement
  # AccreditationTotal represents persisted aggregate counts of accreditations
  # within the RepresentationManagement domain.
  #
  # This model is used to track accreditation totals over time for reporting,
  # analytics, and API responses. Records typically store summary information
  # such as the total number of accredited entities for a given period,
  # category, or source system, rather than individual accreditation records.
  #
  # Example usage:
  #
  #   # Create or update a total for a specific date or grouping
  #   RepresentationManagement::AccreditationTotal.create!(
  #     total_count: 123,
  #     as_of_date: Date.current
  #   )
  #
  #   # Retrieve the most recent accreditation total
  #   latest_total = RepresentationManagement::AccreditationTotal.order(as_of_date: :desc).first
  #
  #   # Use the total in an API response or report
  #   latest_total.total_count
  #
  class AccreditationTotal < ApplicationRecord
  end
end
