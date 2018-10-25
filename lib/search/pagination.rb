# frozen_string_literal: true

module Search
  # A Utility class encapsulating logic to calculate pagination offsets from a given results set.
  #
  # @attr_reader [Integer] total
  # @attr_reader [Integer, nil] next_offset
  # @attr_reader [Integer, nil] previous_offset
  # @param (see Pagination#initialize)
  #
  class Pagination
    # Default size for offset is 20 per page, max is 50.
    OFFSET_LIMIT = 20

    attr_reader :total
    attr_reader :next_offset
    attr_reader :previous_offset

    # @param [Hash] raw_body a Hash from the 'web' object found in the results response
    #
    def initialize(raw_body)
      @total = raw_body.dig('total')
      @next_offset = raw_body.dig('next_offset')
      @previous_offset = get_previous_offset
    end

    # @return [Hash] pagination_object a Hash including next and previous offset
    #
    def object
      pagination_object
    end

    private

    # Calculate the previous_offset value for the instance's given raw_body object
    #
    # @return [Integer, nil] offset returns the previous_offset for the current request, or nil if first page
    #
    def get_previous_offset
      return nil if next_offset == OFFSET_LIMIT # We're on the first page

      if next_offset.blank? && total > OFFSET_LIMIT # We're at the last page of results
        remainder = total % OFFSET_LIMIT
        return total - (remainder + OFFSET_LIMIT)
      end

      offset = next_offset - (2 * OFFSET_LIMIT)
      [offset, 0].max
    end

    def pagination_object
      {
        'next' => next_offset,
        'previous' => previous_offset
      }
    end
  end
end
