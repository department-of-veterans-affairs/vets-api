# frozen_string_literal: true

module SortableRecords
  extend ActiveSupport::Concern

  private

  # Sorts records based on their default_sort_by configuration
  # @param records [Array] Array of Vets::Model objects with default_sort_by defined
  # @param sort_param [String, nil] 'asc' for ascending, anything else for descending (default)
  # @return [Array] Sorted array
  # @example
  #   # Descending (default) - most recent first
  #   sort_records(allergies, nil)
  #   # Ascending - oldest first
  #   sort_records(allergies, 'asc')
  def sort_records(records, sort_param = nil)
    sorted = records.sort
    sort_param == 'asc' ? sorted.reverse : sorted
  end
end
