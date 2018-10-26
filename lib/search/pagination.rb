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
    RESULTS_PER_PAGE = 10

    attr_reader :next_offset
    attr_reader :total_pages

    # @param [Hash] raw_body a Hash from the 'web' object found in the results response
    #
    def initialize(raw_body)
      @next_offset = raw_body.dig('next_offset')
      @total_pages = (raw_body.dig('total') / RESULTS_PER_PAGE.to_f).ceil
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
        (next_offset / RESULTS_PER_PAGE.to_f).floor
      end
    end

    def pagination_object
      {
        'current_page' => [current_page, total_pages].min,
        'total_pages' => total_pages,
        'results_per_page' => RESULTS_PER_PAGE
      }
    end
  end
end
