# frozen_string_literal: true

require 'vets/model'

module EVSS
  module Letters
    ##
    # Model for a user's military service
    #
    # @!attribute branch
    #   @return [String] The relevant branch of the military
    # @!attribute character_of_service
    #   @return [String] The character of the veteran's service
    #   (i.e. "HONORABLE", "OTHER_THAN_HONORABLE", "GENERAL")
    # @!attribute entered_date
    #   @return [DateTime] The date the veteran entered service
    # @!attribute released_date
    #   @return [DateTime] The date the veteran was released from service
    #
    class MilitaryService
      include Vets::Model

      attribute :branch, String
      attribute :character_of_service, String
      attribute :entered_date, DateTime
      attribute :released_date, DateTime
    end
  end
end
