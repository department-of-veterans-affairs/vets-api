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

    # Calculate the previous_offset value for the given raw_body object
    #
    # @return [Integer, nil] offset returns the previous_offset for the current request, or nil if first page
    #
    def get_previous_offset
      # If next_offset is blank we're at the last page of results
      if next_offset.blank?
        remainder = total % OFFSET_LIMIT
        return total - (remainder + OFFSET_LIMIT)
      end

      offset = next_offset - (2 * OFFSET_LIMIT)
      return offset if offset.positive?
    end

    def pagination_object
      {
        'next' => next_offset,
        'previous' => previous_offset
      }
    end
  end
end
