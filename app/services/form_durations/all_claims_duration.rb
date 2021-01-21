# frozen_string_literal: true

module FormDurations
  ##
  # A class responsible for knowing about and returning the All Claims Forms 1 year expiration time frame
  #
  class AllClaimsDuration
    ##
    # Builds a FormDurations::AllClaimsDuration instance from given options
    #
    # @return [FormDurations::AllClaimsDuration] an instance of this class
    #
    def self.build
      new
    end

    ##
    # Gets the All Claims Form's expiration duration
    #
    # @return [ActiveSupport::Duration] 1 year
    #
    def span
      1.year
    end
  end
end
