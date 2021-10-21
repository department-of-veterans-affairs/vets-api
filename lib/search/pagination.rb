# frozen_string_literal: true

module Search
  # A Utility class encapsulating logic to calculate pagination offsets from a given results set.
  #
  # @attr_reader [Integer] total
  # @param (see Pagination#initialize)
  #
  class Pagination
    # Default size for per-request results count is 20 per page, max is 50.
    # Our design choice is to display 10 results per page.
    #
    # @see https://search.usa.gov/sites/6277/api_instructions
    #
    ENTRIES_PER_PAGE = 10

    # Due to Search.gov's offset max of 999, we cannot view pages
    # where the offset param exceeds 999.  This influences our:
    #   - total_viewable_pages
    #   - total_viewable_entries
    #
    # @see https://search.usa.gov/sites/7378/api_instructions under `offset`
    #
    OFFSET_LIMIT = 999

    attr_reader :next_offset, :total_entries, :total_pages

    # @param [Hash] raw_body a Hash from the 'web' object found in the results response
    #
    def initialize(raw_body)
      @next_offset = raw_body.dig('web', 'next_offset')
      @total_entries = raw_body.dig('web', 'total')
      @total_pages = (total_entries / ENTRIES_PER_PAGE.to_f).ceil
    end

    # @return [Hash] pagination_object a Hash including pagination details
    #
    def object
      pagination_object
    end

    private

    def current_page
      case next_offset
      when nil
        total_pages.to_i
      else
        (next_offset / ENTRIES_PER_PAGE.to_f).floor
      end
    end

    def pagination_object
      {
        'current_page' => [current_page, total_viewable_pages].min,
        'per_page' => ENTRIES_PER_PAGE,
        'total_pages' => total_viewable_pages,
        'total_entries' => total_viewable_entries
      }
    end

    def total_viewable_pages
      [total_pages, maximum_viewable_pages].min
    end

    def maximum_viewable_pages
      (OFFSET_LIMIT / ENTRIES_PER_PAGE.to_f).floor
    end

    def total_viewable_entries
      [total_entries, maximum_viewable_entries].min
    end

    def maximum_viewable_entries
      (ENTRIES_PER_PAGE * total_viewable_pages) + (ENTRIES_PER_PAGE - 1)
    end
  end
end
