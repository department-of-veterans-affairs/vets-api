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

    attr_reader :next_offset
    attr_reader :total_entries
    attr_reader :total_pages

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
        'current_page' => [current_page, total_pages].min,
        'per_page' => ENTRIES_PER_PAGE,
        'total_pages' => total_pages,
        'total_entries' => total_entries
      }
    end
  end
end
