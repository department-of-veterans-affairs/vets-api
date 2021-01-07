# frozen_string_literal: true

module FormDurations
  ##
  # A class responsible for knowing about and returning the standard 60 day expiration duration
  #
  class StandardDuration
    ##
    # Builds a FormDurations::StandardDuration instance from given options
    #
    # @return [FormDurations::StandardDuration] an instance of this class
    #
    def self.build
      new
    end

    ##
    # Gets the standard the expiration duration
    #
    # @return [ActiveSupport::Duration] 60 days
    #
    def span
      60.days
    end
  end
end
