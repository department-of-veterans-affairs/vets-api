# frozen_string_literal: true

module FormDurations
  ##
  # A class responsible for knowing about and returning the custom expiration duration
  #
  # @!attribute interval
  #   @return [Integer]
  class CustomDuration
    attr_reader :interval

    ##
    # Builds a FormDurations::CustomDuration instance from a given interval
    #
    # @param interval [Integer] the custom expiration number
    # @return [FormDurations::CustomDuration] an instance of this class
    #
    def self.build(interval)
      new(interval)
    end

    def initialize(interval)
      @interval = interval
    end

    ##
    # Gets the custom expiration duration
    #
    # @return [ActiveSupport::Duration] 60 days as the default value or interval days if specified
    #
    def span
      return 60.days if interval.zero?

      interval.days
    end
  end
end
